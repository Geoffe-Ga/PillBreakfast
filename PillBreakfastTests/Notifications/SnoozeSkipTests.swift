import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct SnoozeSkipTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func skipWritesSkippedEventAndClearsTheCount() throws {
    let context = try makeContext()
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let dose = ScheduledDose(hour: 8, minute: 0, quantity: 2)
    dose.medication = med
    med.schedule = [dose]
    context.insert(med)
    let day = Date(timeIntervalSince1970: 1_700_000_000)
    try SnoozeRecordStore.increment(scheduledDoseID: dose.id, on: day, at: day, in: context)
    try SnoozeRecordStore.increment(scheduledDoseID: dose.id, on: day, at: day, in: context)
    try SnoozeRecordStore.increment(scheduledDoseID: dose.id, on: day, at: day, in: context)
    try context.save()

    let original = Date(timeIntervalSince1970: 1_700_000_500)
    try SnoozeSkip.skip(scheduledDoseID: dose.id, originalScheduledFor: original, at: day, in: context)

    let events = try context.fetch(FetchDescriptor<DoseEvent>())
    #expect(events.count == 1)
    let event = try #require(events.first)
    #expect(event.status == .skipped)
    #expect(event.quantity == 2)
    #expect(event.medication?.id == med.id)
    // The skip clears the occurrence's snooze count.
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: dose.id, on: day, in: context) == 0)
  }

  @Test func skipThrowsWhenDoseNotFound() throws {
    let context = try makeContext()
    #expect(throws: SnoozeSkip.SkipError.doseNotFound) {
      try SnoozeSkip.skip(scheduledDoseID: UUID(), originalScheduledFor: .now, in: context)
    }
  }
}
