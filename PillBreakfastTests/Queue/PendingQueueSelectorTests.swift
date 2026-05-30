import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PendingQueueSelectorTests {
  // MARK: - Fixtures

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  /// Gregorian calendar pinned to a fixed timezone so day boundaries and weekday
  /// are deterministic regardless of the simulator's locale.
  private func calendar(_ tzIdentifier: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: tzIdentifier))
    return calendar
  }

  private func date(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
    in calendar: Calendar
  ) throws -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return try #require(calendar.date(from: components))
  }

  private func scheduledDose(_ hour: Int, _ minute: Int, quantity: Int = 1, daysOfWeek: [Int] = []) -> ScheduledDose {
    ScheduledDose(hour: hour, minute: minute, quantity: quantity, daysOfWeek: daysOfWeek)
  }

  @discardableResult
  private func insertMed(
    in context: ModelContext,
    kind: MedicationKind = .maintenance,
    isArchived: Bool = false,
    schedule: [ScheduledDose]
  ) throws -> Medication {
    let med = Medication(
      displayName: "Test Med",
      unitForm: .tablet,
      kind: kind,
      isArchived: isArchived,
      schedule: schedule
    )
    context.insert(med)
    try context.save()
    return med
  }

  private func logDose(
    _ med: Medication,
    scheduledFor: Date,
    status: DoseStatus = .taken,
    in context: ModelContext
  ) throws {
    context.insert(DoseEvent(
      medication: med,
      scheduledFor: scheduledFor,
      takenAt: scheduledFor,
      quantity: 1,
      status: status,
      loggedOn: .watch
    ))
    try context.save()
  }

  // MARK: - Window

  @Test func doseWithinWindowIsPending() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0, quantity: 2)])
    let now = try date(2026, 5, 29, 8, 5, in: cal)

    let result = try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context)

    #expect(result.count == 1)
    let dose = try #require(result.first)
    #expect(dose.medicationID == med.id)
    #expect(dose.quantity == 2)
    #expect(try dose.scheduledFor == date(2026, 5, 29, 8, 0, in: cal))
  }

  @Test func doseTooEarlyIsEmpty() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    // 66 minutes before the 8:00 dose.
    let now = try date(2026, 5, 29, 6, 54, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func doseTooLateIsEmpty() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    // 65 minutes after the 8:00 dose.
    let now = try date(2026, 5, 29, 9, 5, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func windowBoundaryAtExactly60MinutesIsInclusive() throws {
    // SPEC says "within ± 60 min"; the boundary is inclusive. (The issue labels
    // 7:00 vs an 8:00 dose as "61 min early", but it is exactly 60 — pinned here
    // explicitly rather than relying on that label.)
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    let now = try date(2026, 5, 29, 7, 0, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).count == 1)
  }

  // MARK: - Already logged

  @Test func alreadyTakenTodayIsEmpty() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    try logDose(med, scheduledFor: date(2026, 5, 29, 8, 0, in: cal), in: context)
    let now = try date(2026, 5, 29, 8, 5, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func skippedTodayIsAlsoSuppressed() throws {
    // Logging a skip still produces a DoseEvent for the slot; the user has acted
    // on it, so it should not resurface.
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    try logDose(med, scheduledFor: date(2026, 5, 29, 8, 0, in: cal), status: .skipped, in: context)
    let now = try date(2026, 5, 29, 8, 5, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func proactivelyLoggedYesterdayIsSuppressedToday() throws {
    // takenAt is late yesterday (23:00), but scheduledFor is today's 8 AM
    // slot — the user pre-logged the slot at the end of the previous day.
    // The selector running today at 8:05 must read this as "already logged"
    // and suppress the slot; otherwise a duplicate-log is the silent
    // failure mode the wider takenAt window is meant to prevent.
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    let todayAt8 = try date(2026, 5, 29, 8, 0, in: cal)
    let yesterdayLateNight = try #require(
      cal.date(byAdding: .hour, value: -1, to: cal.startOfDay(for: todayAt8))
    ) // 23:00 yesterday

    context.insert(DoseEvent(
      medication: med,
      scheduledFor: todayAt8,
      takenAt: yesterdayLateNight,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    ))
    try context.save()

    let now = try date(2026, 5, 29, 8, 5, in: cal)
    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func fetchLimitHitThrowsRatherThanReturnsTruncated() throws {
    // Seed enough in-window events to trip `fetchLimit` (200). The selector
    // must throw rather than return a truncated "already logged" set — a
    // silent truncation would resurface previously-logged slots as still
    // pending, opening a duplicate-log path on safety-critical meds.
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    let todayAt8 = try date(2026, 5, 29, 8, 0, in: cal)

    for offset in 0 ..< PendingQueueSelector.fetchLimit {
      let takenAt = try #require(
        cal.date(byAdding: .minute, value: offset, to: cal.startOfDay(for: todayAt8))
      )
      context.insert(DoseEvent(
        medication: med,
        scheduledFor: todayAt8,
        takenAt: takenAt,
        quantity: 1,
        status: .taken,
        loggedOn: .watch
      ))
    }
    try context.save()

    let now = try date(2026, 5, 29, 8, 5, in: cal)
    #expect(throws: PendingQueueSelector.CalendarError.fetchLimitReached) {
      _ = try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context)
    }
  }

  @Test func outOfWindowHistoryDoesNotAffectResult() throws {
    // Regression guard: the old per-slot `med.doseEvents.contains(...)`
    // hydrated every historical event. The bounded fetch must not count
    // out-of-window events as "already logged" — today's slot must still
    // surface even when the same slot has been filled on 60 prior days.
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    let todayAt8 = try date(2026, 5, 29, 8, 0, in: cal)

    // Seed via `Calendar.date(byAdding:)` rather than negative `day:`
    // components, which can roll in surprising ways across short months.
    for daysAgo in 1 ... 60 {
      let priorDay = try #require(cal.date(byAdding: .day, value: -daysAgo, to: todayAt8))
      try logDose(med, scheduledFor: priorDay, in: context)
    }

    let now = try date(2026, 5, 29, 8, 5, in: cal)
    let result = try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context)
    #expect(result.count == 1)
    #expect(try #require(result.first).scheduledFor == todayAt8)
  }

  @Test func loggingOneSlotDoesNotSuppressAnotherSlot() throws {
    // A twice-daily med with both slots inside the window: logging the 8:00 dose
    // must not hide the 8:30 dose. (A coarse same-day match would wrongly drop both.)
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    let med = try insertMed(in: context, schedule: [scheduledDose(8, 0), scheduledDose(8, 30)])
    try logDose(med, scheduledFor: date(2026, 5, 29, 8, 0, in: cal), in: context)
    let now = try date(2026, 5, 29, 8, 15, in: cal)

    let result = try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context)
    #expect(result.count == 1)
    #expect(try #require(result.first).scheduledFor == date(2026, 5, 29, 8, 30, in: cal))
  }

  // MARK: - Day-of-week (ISO weekday handling)

  @Test func weekdayOnlyDoseSkippedOnWeekend() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    // ISO Mon–Fri.
    try insertMed(in: context, schedule: [scheduledDose(8, 0, daysOfWeek: [1, 2, 3, 4, 5])])
    let now = try date(2026, 5, 30, 8, 5, in: cal) // Saturday
    #expect(cal.component(.weekday, from: now) == 7) // Gregorian Saturday

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func emptyDaysOfWeekMatchesEveryDay() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0, daysOfWeek: [])])
    let now = try date(2026, 5, 30, 8, 5, in: cal) // Saturday

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).count == 1)
  }

  @Test func isoSundayDoseMatchesOnSunday() throws {
    // ISO Sunday is 7, but Calendar's Gregorian Sunday is 1. A naive raw compare
    // (daysOfWeek.contains(calendar.weekday)) would miss this entirely.
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0, daysOfWeek: [7])]) // ISO Sunday
    let now = try date(2026, 5, 31, 8, 5, in: cal) // Sunday
    #expect(cal.component(.weekday, from: now) == 1) // Gregorian Sunday

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).count == 1)
  }

  @Test func isoMondayDoseMatchesOnMonday() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0, daysOfWeek: [1])]) // ISO Monday
    let now = try date(2026, 6, 1, 8, 5, in: cal) // Monday
    #expect(cal.component(.weekday, from: now) == 2) // Gregorian Monday

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).count == 1)
  }

  // MARK: - Exclusions

  @Test func archivedMedicationIsExcluded() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, isArchived: true, schedule: [scheduledDose(8, 0)])
    let now = try date(2026, 5, 29, 8, 5, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  @Test func prnMedicationIsExcluded() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    try insertMed(in: context, kind: .prn, schedule: [scheduledDose(8, 0)])
    let now = try date(2026, 5, 29, 8, 5, in: cal)

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context).isEmpty)
  }

  // MARK: - Ordering

  @Test func multipleDosesAreSortedByScheduledTime() throws {
    let cal = try calendar("America/New_York")
    let context = try makeContext()
    // Insert out of order to prove the sort.
    try insertMed(in: context, schedule: [scheduledDose(8, 30), scheduledDose(8, 0)])
    let now = try date(2026, 5, 29, 8, 15, in: cal)

    let result = try PendingQueueSelector(calendar: cal).pendingDoses(at: now, in: context)
    #expect(try result.map(\.scheduledFor) == [
      date(2026, 5, 29, 8, 0, in: cal),
      date(2026, 5, 29, 8, 30, in: cal),
    ])
  }

  // MARK: - Timezone determinism

  @Test func usesInjectedCalendarNotCurrent() throws {
    // Same store, same absolute instant — only the injected calendar differs.
    // At 12:05 UTC an 8:00-local daily dose is 5 min away in Eastern (08:05 EDT)
    // but ~3h away in Pacific (05:05 PDT). Proves the selector honours the
    // injected calendar's timezone and never reads Calendar.current.
    let utc = try calendar("UTC")
    let context = try makeContext()
    try insertMed(in: context, schedule: [scheduledDose(8, 0)])
    let now = try date(2026, 5, 29, 12, 5, in: utc)

    let eastern = try PendingQueueSelector(calendar: calendar("America/New_York"))
      .pendingDoses(at: now, in: context)
    let pacific = try PendingQueueSelector(calendar: calendar("America/Los_Angeles"))
      .pendingDoses(at: now, in: context)

    #expect(eastern.count == 1)
    #expect(pacific.isEmpty)
  }

  // MARK: - Weekday conversion unit

  @Test func isoWeekdayConversionCoversAllDays() {
    // Gregorian (Sun=1…Sat=7) -> ISO (Mon=1…Sun=7).
    #expect(PendingQueueSelector.isoWeekday(fromCalendar: 1) == 7) // Sunday
    #expect(PendingQueueSelector.isoWeekday(fromCalendar: 2) == 1) // Monday
    #expect(PendingQueueSelector.isoWeekday(fromCalendar: 7) == 6) // Saturday
  }
}
