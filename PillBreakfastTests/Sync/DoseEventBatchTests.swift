import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct DoseEventBatchTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func sampleDTO(id: UUID, medicationID: UUID, notes: String? = nil) -> DoseEventDTO {
    DoseEventDTO(
      id: id,
      medicationID: medicationID,
      scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
      takenAt: Date(timeIntervalSince1970: 1_700_000_100),
      quantity: 1,
      status: .taken,
      loggedOn: .watch,
      notes: notes,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: UUID(), ingredientName: "Cholecalciferol", totalMg: 2000)]
    )
  }

  @Test func batchCodableRoundTrip() throws {
    let batch = DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: UUID())])
    let decoded = try JSONDecoder().decode(DoseEventBatch.self, from: JSONEncoder().encode(batch))
    #expect(decoded == batch)
  }

  @Test func mergeInsertsLinkedToMedication() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let batch = DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: medication.id)])
    let result = try DoseEventBatchMerger.merge(batch, into: context)

    #expect(result.inserted == 1)
    #expect(result.updated == 0)
    let stored = try context.fetch(FetchDescriptor<DoseEvent>())
    #expect(stored.count == 1)
    #expect(stored.first?.medication?.id == medication.id)
    #expect(stored.first?.ingredientAmounts.first?.totalMg == 2000)
  }

  @Test func mergeIsIdempotentByID() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let eventID = UUID()
    let batch = DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id)])
    _ = try DoseEventBatchMerger.merge(batch, into: context)
    let second = try DoseEventBatchMerger.merge(batch, into: context)

    #expect(second.inserted == 0)
    #expect(second.updated == 0)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).count == 1) // no duplicate
  }

  @Test func mergePreservesNotesOnInsert() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let batch = DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: medication.id, notes: "with food")])
    _ = try DoseEventBatchMerger.merge(batch, into: context)

    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).notes == "with food")
  }

  @Test func mergeDoesNotClobberNotesOnNilResend() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let eventID = UUID()
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: "with food")]),
      into: context
    )
    // A re-send carrying no note must not erase the existing one.
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: nil)]),
      into: context
    )

    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).notes == "with food")
  }

  @Test func mergeSkipsUpdateOnIdenticalNoteResend() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let eventID = UUID()
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: "with food")]),
      into: context
    )
    let second = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: "with food")]),
      into: context
    )

    #expect(second.inserted == 0)
    #expect(second.updated == 0)
    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).notes == "with food")
  }

  @Test func mergeUpdatesNotesOnNonNilResend() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let eventID = UUID()
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: "with food")]),
      into: context
    )
    // A re-send carrying a new note replaces the existing one.
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id, notes: "without food")]),
      into: context
    )

    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).notes == "without food")
  }

  @Test func mergeSkipsEventWithUnknownMedication() throws {
    let context = try makeInMemoryContext()
    let batch = DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: UUID())])
    let result = try DoseEventBatchMerger.merge(batch, into: context)

    #expect(result.inserted == 0)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).isEmpty)
  }

  @Test func mergeStampsDenormalizedMedicationIDOnInsert() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: medication.id)]),
      into: context
    )
    // The denormalized field is stamped from the DTO so the hot-path reader sees
    // the id without faulting the `medication` relationship.
    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).medicationID == medication.id)
  }

  @Test func makeBatchCarriesDenormalizedMedicationIDThroughJSON() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(medication)
    let event = DoseEvent(
      medication: medication,
      medicationID: medication.id,
      takenAt: Date(timeIntervalSince1970: 1_700_000_000),
      quantity: 2,
      status: .taken,
      loggedOn: .watch
    )
    context.insert(event)
    try context.save()

    // makeBatch → JSON → decode mirrors the WCSession transferFile path.
    let batch = DoseEventBatchTransfer.makeBatch(from: [event])
    let wire = try JSONDecoder().decode(DoseEventBatch.self, from: JSONEncoder().encode(batch))
    #expect(wire.events.first?.medicationID == medication.id)
  }

  @Test func mergeKeepsOriginalMedicationIDWhenResendMismatches() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(medication)
    try context.save()

    let eventID = UUID()
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: medication.id)]),
      into: context
    )
    // A corrupt re-send carrying a different medicationID must not rewrite the
    // immutable history (the merger logs and keeps the original).
    _ = try DoseEventBatchMerger.merge(
      DoseEventBatch(events: [sampleDTO(id: eventID, medicationID: UUID())]),
      into: context
    )
    #expect(try #require(context.fetch(FetchDescriptor<DoseEvent>()).first).medicationID == medication.id)
  }
}
