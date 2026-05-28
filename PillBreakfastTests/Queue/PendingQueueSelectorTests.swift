import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PendingQueueSelectorTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func skeletonReturnsNoPendingDosesEvenWithAScheduledMed() throws {
    let context = try makeInMemoryContext()
    let medication = Medication(displayName: "Stub Lithium 300mg", unitForm: .tablet, kind: .maintenance)
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(medication)
    try context.save()

    // Skeleton always returns [] (real window logic is EPIC_03_ISSUE_06).
    let pending = try PendingQueueSelector.pendingDoses(at: .now, in: context)
    #expect(pending.isEmpty)
  }
}
