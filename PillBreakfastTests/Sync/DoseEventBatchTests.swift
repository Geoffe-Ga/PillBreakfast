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
    #expect(second.updated == 1)
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

  @Test func mergeSkipsEventWithUnknownMedication() throws {
    let context = try makeInMemoryContext()
    let batch = DoseEventBatch(events: [sampleDTO(id: UUID(), medicationID: UUID())])
    let result = try DoseEventBatchMerger.merge(batch, into: context)

    #expect(result.inserted == 0)
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).isEmpty)
  }
}
