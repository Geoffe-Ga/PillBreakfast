import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct DoseEventMigratorTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func backfillsSentinelFromRelationship() throws {
    let context = try makeInMemoryContext()
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    // A legacy row: linked to the medication but still carrying the sentinel
    // (as lightweight migration would have seated it).
    let legacy = DoseEvent(
      medication: med,
      medicationID: DoseEvent.unlinkedMedicationID,
      takenAt: .now,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    )
    context.insert(legacy)
    try context.save()

    let count = try DoseEventMigrator.backfillMedicationIDs(in: context)
    #expect(count == 1)
    #expect(legacy.medicationID == med.id)
  }

  @Test func isIdempotentAcrossRuns() throws {
    let context = try makeInMemoryContext()
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    let legacy = DoseEvent(
      medication: med,
      medicationID: DoseEvent.unlinkedMedicationID,
      takenAt: .now,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    )
    context.insert(legacy)
    try context.save()

    _ = try DoseEventMigrator.backfillMedicationIDs(in: context)
    // Second run finds no sentinel rows left to fix.
    #expect(try DoseEventMigrator.backfillMedicationIDs(in: context) == 0)
  }

  @Test func leavesSentinelWhenRelationshipIsNil() throws {
    let context = try makeInMemoryContext()
    // An orphaned legacy row (its medication was deleted before the field existed):
    // there is no source to recover the id from, so the sentinel stays.
    let orphan = DoseEvent(
      medicationID: DoseEvent.unlinkedMedicationID,
      takenAt: .now,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    )
    context.insert(orphan)
    try context.save()

    let count = try DoseEventMigrator.backfillMedicationIDs(in: context)
    #expect(count == 0)
    #expect(orphan.medicationID == DoseEvent.unlinkedMedicationID)
  }

  @Test func doesNotTouchAlreadyStampedRows() throws {
    let context = try makeInMemoryContext()
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    let fresh = DoseEvent(
      medication: med,
      medicationID: med.id,
      takenAt: .now,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    )
    context.insert(fresh)
    try context.save()

    #expect(try DoseEventMigrator.backfillMedicationIDs(in: context) == 0)
    #expect(fresh.medicationID == med.id)
  }
}
