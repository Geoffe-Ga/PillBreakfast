import Foundation
import os
import SwiftData
import WatchConnectivity

/// Reverse-sync of logged doses: the watch transfers `DoseEvent`s to the iPhone
/// as a small JSON file (queued by `WCSession.transferFile`, so it survives the
/// iPhone being asleep), and the iPhone merges them idempotently by `id`.
public enum DoseEventBatchTransfer {
  /// Metadata key/value identifying our file transfers. `nonisolated` so the
  /// WCSession delegate (which is nonisolated) can read them without a hop.
  public nonisolated static let metadataKind = "doseEventBatch"
  public nonisolated static let metadataKindKey = "kind"

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "ReverseSync")

  /// Builds the wire batch from live models (reads `@Model` state on the main actor).
  /// Events without a medication are skipped — they can't be linked on the iPhone.
  @MainActor
  public static func makeBatch(from events: [DoseEvent]) -> DoseEventBatch {
    DoseEventBatch(events: events.compactMap { event in
      guard let medicationID = event.medication?.id else {
        logger.warning("Dose event \(event.id, privacy: .public) has no medication; not transferring.")
        return nil
      }
      return DoseEventDTO(
        id: event.id,
        medicationID: medicationID,
        scheduledFor: event.scheduledFor,
        takenAt: event.takenAt,
        quantity: event.quantity,
        status: event.status,
        loggedOn: event.loggedOn,
        notes: event.notes,
        ingredientAmounts: event.ingredientAmounts
      )
    })
  }

  /// Encodes the events to a temp JSON file and queues a file transfer to the iPhone.
  @MainActor
  public static func transfer(_ events: [DoseEvent]) throws {
    let batch = makeBatch(from: events)
    guard !batch.events.isEmpty else { return }
    guard WCSession.default.activationState == .activated else {
      logger.warning("WCSession not activated; skipping dose transfer.")
      return
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("doseEvents-\(UUID().uuidString).json")
    // WC copies the file before transferFile returns, so the source can go now.
    defer {
      do { try FileManager.default.removeItem(at: url) }
      catch { logger.debug("Temp dose-event file cleanup failed: \(error.localizedDescription, privacy: .public)") }
    }
    try JSONEncoder().encode(batch).write(to: url)
    // transferFile queues the (already-copied) payload until the iPhone is reachable.
    WCSession.default.transferFile(url, metadata: [metadataKindKey: metadataKind])
  }

  /// Decodes a received batch file and merges it into the local store.
  @MainActor
  @discardableResult
  public static func merge(fileData: Data, into context: ModelContext) throws -> (inserted: Int, updated: Int) {
    let batch = try JSONDecoder().decode(DoseEventBatch.self, from: fileData)
    return try DoseEventBatchMerger.merge(batch, into: context)
  }
}

/// Idempotent upsert of a `DoseEventBatch` keyed on `DoseEvent.id`.
@MainActor
public enum DoseEventBatchMerger {
  @discardableResult
  public static func merge(
    _ batch: DoseEventBatch,
    into context: ModelContext
  ) throws -> (inserted: Int, updated: Int) {
    var inserted = 0
    var updated = 0
    // One or two fetches per event. Fine for the 1-at-a-time live transfer; if a
    // bulk replay (e.g. new-phone backfill) ever sends large batches, fetch the
    // existing events and medications in bulk first rather than per-event.
    for dto in batch.events {
      let eventID = dto.id
      let existing = try context.fetch(
        FetchDescriptor<DoseEvent>(predicate: #Predicate { $0.id == eventID })
      ).first

      if let existing {
        // A re-sent event is immutable history except notes. Only write — and
        // only count `updated` — when the re-send actually carries a different
        // note. A `nil`-on-re-send doesn't erase the existing note, and a
        // same-value re-send doesn't dirty the SwiftData row or inflate the
        // merge log.
        if let newNotes = dto.notes, newNotes != existing.notes {
          existing.notes = newNotes
          updated += 1
        }
      } else {
        let medicationID = dto.medicationID
        guard let medication = try context.fetch(
          FetchDescriptor<Medication>(predicate: #Predicate { $0.id == medicationID })
        ).first else {
          continue // medication not on this device yet — skip rather than orphan
        }
        context.insert(
          DoseEvent(
            id: dto.id,
            medication: medication,
            scheduledFor: dto.scheduledFor,
            takenAt: dto.takenAt,
            quantity: dto.quantity,
            status: dto.status,
            loggedOn: dto.loggedOn,
            notes: dto.notes,
            ingredientAmounts: dto.ingredientAmounts
          )
        )
        inserted += 1
      }
    }
    try context.save()
    return (inserted, updated)
  }
}
