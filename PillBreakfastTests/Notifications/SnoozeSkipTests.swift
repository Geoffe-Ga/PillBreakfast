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

  @Test func skipTheNextMorningStillClearsALateNightSnoozeCount() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let context = try makeContext()
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let dose = ScheduledDose(hour: 22, minute: 0, quantity: 1)
    dose.medication = med
    med.schedule = [dose]
    context.insert(med)

    // Dose scheduled for 10 PM on May 15; the user snoozes it twice late that night.
    var comps = DateComponents()
    comps.year = 2026; comps.month = 5; comps.day = 15; comps.hour = 22; comps.minute = 0
    let scheduledFor = try #require(calendar.date(from: comps))
    let lateNight = try #require(calendar.date(bySettingHour: 23, minute: 58, second: 0, of: scheduledFor))
    try SnoozeRecordStore.increment(scheduledDoseID: dose.id, on: scheduledFor, at: lateNight, in: context, calendar: calendar)
    try SnoozeRecordStore.increment(scheduledDoseID: dose.id, on: scheduledFor, at: lateNight, in: context, calendar: calendar)

    // They skip it the next morning — a different calendar day from `now`.
    let nextMorning = try #require(calendar.date(byAdding: .day, value: 1, to: scheduledFor))
    try SnoozeSkip.skip(
      scheduledDoseID: dose.id,
      originalScheduledFor: scheduledFor,
      at: nextMorning,
      in: context,
      calendar: calendar
    )

    // The skipped dose is logged and the late-night count is cleared — no orphan row
    // keyed on the wall-clock skip day.
    #expect(try context.fetch(FetchDescriptor<DoseEvent>()).count == 1)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: dose.id, on: scheduledFor, in: context, calendar: calendar) == 0)
  }

  @Test func skipThrowsWhenDoseNotFound() throws {
    let context = try makeContext()
    #expect(throws: SnoozeSkip.SkipError.doseNotFound) {
      try SnoozeSkip.skip(scheduledDoseID: UUID(), originalScheduledFor: .now, in: context)
    }
  }
}
