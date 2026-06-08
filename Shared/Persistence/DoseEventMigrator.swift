import Foundation
import os
import SwiftData

/// One-time backfill of `DoseEvent.medicationID` for rows that predate the
/// denormalized field. Lightweight migration seats `DoseEvent.unlinkedMedicationID`
/// on those rows; this restores the real id from the live `medication` relationship
/// so the hot-path reader (`PendingQueueSelector.loggedSlotKeys`) sees correct ids
/// without a per-event relationship fault.
///
/// Idempotent and cheap on the steady state: it fetches only rows still carrying
/// the sentinel, so once backfilled (and for a fresh store) the predicate matches
/// nothing. Safe to run on every launch.
@MainActor
public enum DoseEventMigrator {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Migration")

  /// Returns the number of rows backfilled. A row whose `medication` relationship
  /// is nil (the medication was deleted before this field existed) keeps the
  /// sentinel — there's no source to recover the id from, and such a row never
  /// matches a real medication's slot key, so leaving it is harmless.
  @discardableResult
  public static func backfillMedicationIDs(in context: ModelContext) throws -> Int {
    let sentinel = DoseEvent.unlinkedMedicationID
    let stale = try context.fetch(
      FetchDescriptor<DoseEvent>(predicate: #Predicate { $0.medicationID == sentinel })
    )
    guard !stale.isEmpty else { return 0 }

    var backfilled = 0
    for event in stale {
      guard let id = event.medication?.id else { continue }
      event.medicationID = id
      backfilled += 1
    }
    if context.hasChanges {
      try context.save()
    }
    if backfilled > 0 {
      logger.info("Backfilled medicationID on \(backfilled, privacy: .public) legacy dose event(s).")
    }
    return backfilled
  }
}
