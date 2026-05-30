import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct HistoryTabViewTests {
  /// Pin the calendar to UTC so the test doesn't drift across the simulator's
  /// local timezone — `windowStart` and `days(...)` both anchor on
  /// `Calendar.startOfDay`, which is timezone-dependent.
  private static func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    if let utc = TimeZone(identifier: "UTC") {
      calendar.timeZone = utc
    }
    return calendar
  }

  /// Midday UTC for the given Y/M/D — `12:00` so a test reference is well
  /// inside the day and doesn't accidentally straddle the local-vs-UTC
  /// startOfDay boundary. Use `DateComponents(...)` directly when you need
  /// an exact `00:00` reference (e.g. the spin-guard test).
  private func reference(_ year: Int, _ month: Int, _ day: Int) -> Date {
    let components = DateComponents(timeZone: TimeZone(identifier: "UTC"), year: year, month: month, day: day, hour: 12)
    return Self.utcCalendar().date(from: components) ?? .distantPast
  }

  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func insertEvent(at takenAt: Date, into context: ModelContext, medication: Medication? = nil) {
    context.insert(DoseEvent(
      medication: medication,
      takenAt: takenAt,
      quantity: 1,
      status: .taken,
      loggedOn: .iphone
    ))
  }

  // MARK: - windowStart

  @Test func windowStartIs29DaysBeforeReference() {
    let ref = reference(2026, 5, 30)
    let start = HistoryTabView.windowStart(reference: ref, calendar: Self.utcCalendar())
    let expected = reference(2026, 5, 1)
    #expect(Self.utcCalendar().startOfDay(for: start) == Self.utcCalendar().startOfDay(for: expected))
  }

  @Test func windowStartIsAtStartOfDay() {
    // A reference of "12:00" must still produce the 00:00 start so the predicate
    // captures dose events taken earlier on the oldest day.
    let ref = reference(2026, 5, 30)
    let start = HistoryTabView.windowStart(reference: ref, calendar: Self.utcCalendar())
    let components = Self.utcCalendar().dateComponents([.hour, .minute, .second], from: start)
    #expect(components.hour == 0)
    #expect(components.minute == 0)
    #expect(components.second == 0)
  }

  // MARK: - days(from:reference:calendar:)

  @Test func daysProducesThirtyCells() {
    let ref = reference(2026, 5, 30)
    let cells = HistoryTabView.days(from: [], reference: ref, calendar: Self.utcCalendar())
    #expect(cells.count == HistoryTabView.windowDays)
  }

  @Test func daysAreChronologicalOldestToNewest() {
    let ref = reference(2026, 5, 30)
    let cells = HistoryTabView.days(from: [], reference: ref, calendar: Self.utcCalendar())
    // First cell is the oldest (May 1), last cell is today (May 30).
    #expect(cells.first?.dayOfMonth == 1)
    #expect(cells.last?.dayOfMonth == 30)
    // Strictly increasing dates.
    for index in 1 ..< cells.count {
      #expect(cells[index].date > cells[index - 1].date)
    }
  }

  @Test func daysReportZeroEventsWhenStoreIsEmpty() throws {
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(
      from: events,
      reference: ref,
      calendar: Self.utcCalendar()
    )
    #expect(cells.allSatisfy { $0.eventCount == 0 })
  }

  @Test func daysRollUpEventsByCalendarDay() throws {
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    // Two events on May 30, one event on May 29, one event on May 1 (the
    // oldest in-window day) — each should land in exactly one bucket.
    insertEvent(at: reference(2026, 5, 30), into: context)
    insertEvent(at: reference(2026, 5, 30), into: context)
    insertEvent(at: reference(2026, 5, 29), into: context)
    insertEvent(at: reference(2026, 5, 1), into: context)
    try context.save()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(from: events, reference: ref, calendar: Self.utcCalendar())
    // Key by the day-start `date` — `dayOfMonth` would collide across months
    // and trap `Dictionary(uniqueKeysWithValues:)` on a window like May 15 →
    // June 13.
    let byDate = Dictionary(uniqueKeysWithValues: cells.map { ($0.date, $0.eventCount) })
    #expect(byDate[Self.utcCalendar().startOfDay(for: reference(2026, 5, 30))] == 2)
    #expect(byDate[Self.utcCalendar().startOfDay(for: reference(2026, 5, 29))] == 1)
    #expect(byDate[Self.utcCalendar().startOfDay(for: reference(2026, 5, 1))] == 1)
    // Spot-check an unloaded day stays at zero.
    #expect(byDate[Self.utcCalendar().startOfDay(for: reference(2026, 5, 15))] == 0)
  }

  @Test func daysIgnoreEventsWithNoMatchingBucket() throws {
    // This test exercises the bucket-lookup defensive filter in `days(...)`
    // specifically — the `@Query` predicate's `>= start` is a separate gate
    // and is not what's under test here. Together they form belt-and-suspenders:
    // even if a future predicate change leaks an out-of-window event, the
    // bucket lookup still drops it.
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    // Way before the window (April 1).
    insertEvent(at: reference(2026, 4, 1), into: context)
    // In the window (May 15).
    insertEvent(at: reference(2026, 5, 15), into: context)
    try context.save()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(from: events, reference: ref, calendar: Self.utcCalendar())
    let total = cells.reduce(0) { $0 + $1.eventCount }
    // Only the in-window May 15 event is counted; the April 1 one has no
    // matching bucket key and is silently dropped.
    #expect(total == 1)
  }

  // MARK: - days(...) medication filter

  @Test func daysWithoutFilterCountsEveryEvent() throws {
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let tylenol = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    context.insert(lithium)
    context.insert(tylenol)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: lithium)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: tylenol)
    try context.save()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(
      from: events,
      reference: ref,
      calendar: Self.utcCalendar()
    )
    let total = cells.reduce(0) { $0 + $1.eventCount }
    #expect(total == 2)
  }

  @Test func daysWithFilterScopesToOneMedication() throws {
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let tylenol = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    context.insert(lithium)
    context.insert(tylenol)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: lithium)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: lithium)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: tylenol)
    try context.save()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(
      from: events,
      reference: ref,
      calendar: Self.utcCalendar(),
      filterMedicationID: lithium.id
    )
    let total = cells.reduce(0) { $0 + $1.eventCount }
    // Only the two Lithium events count toward the heatmap intensity; the
    // Tylenol event is silently excluded.
    #expect(total == 2)
  }

  @Test func daysWithFilterDropsOrphanedEvents() throws {
    let ref = reference(2026, 5, 30)
    let context = try makeInMemoryContext()
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(lithium)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: lithium)
    insertEvent(at: reference(2026, 5, 30), into: context, medication: nil)
    try context.save()
    let descriptor = FetchDescriptor<DoseEvent>(sortBy: [SortDescriptor(\.takenAt)])
    let events = try context.fetch(descriptor)
    let cells = HistoryTabView.days(
      from: events,
      reference: ref,
      calendar: Self.utcCalendar(),
      filterMedicationID: lithium.id
    )
    let total = cells.reduce(0) { $0 + $1.eventCount }
    #expect(total == 1)
  }

  // MARK: - MedicationFilterMenu label

  @Test func filterMenuLabelIsAllMedicationsWhenSelectionIsNil() {
    #expect(MedicationFilterMenu.labelText(for: nil, in: []) == "All medications")
  }

  @Test func filterMenuLabelIsMedicationNameWhenSelected() {
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    #expect(MedicationFilterMenu.labelText(for: lithium.id, in: [lithium]) == "Lithium")
  }

  @Test func filterMenuLabelFallsBackToAllWhenSelectionMissing() {
    // A selection that doesn't match any current medication (e.g. the med was
    // hard-deleted) falls back to "All medications" rather than rendering an
    // empty label or trapping.
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    #expect(MedicationFilterMenu.labelText(for: UUID(), in: [lithium]) == "All medications")
  }

  // MARK: - emptyDescription

  @Test func emptyDescriptionWithoutFilterNudgesUserToTheWatch() {
    // The unfiltered empty state reads as "log doses on your watch" so the
    // user knows where to act, not just that the screen is blank.
    let copy = HistoryTabView.emptyDescription(forFilter: nil, in: [])
    #expect(copy.contains("watch"))
  }

  @Test func emptyDescriptionWithFilterNamesTheMedication() {
    // A filtered empty state names the medication so it's clear nothing was
    // logged for *it* specifically rather than a global blank state.
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let copy = HistoryTabView.emptyDescription(forFilter: lithium.id, in: [lithium])
    #expect(copy.contains("Lithium"))
  }

  @Test func emptyDescriptionWithMissingFilterFallsBackToGeneric() {
    // Selection points at a medication that no longer exists (e.g. archived
    // then hard-deleted); fall back to the generic copy rather than
    // rendering "No  doses logged" with a hole where the name would be.
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let copy = HistoryTabView.emptyDescription(forFilter: UUID(), in: [lithium])
    #expect(copy.contains("watch"))
  }

  // MARK: - day-rollover semantics

  @Test func nextDayBoundaryReturnsStartOfFollowingDay() throws {
    // Midday should sleep until the upcoming 00:00.
    let now = reference(2026, 5, 30) // 12:00 UTC
    let next = try #require(HistoryTabView.nextDayBoundary(after: now, calendar: Self.utcCalendar()))
    let expected = try #require(
      Self.utcCalendar().date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 5, day: 31))
    )
    #expect(next == expected)
  }

  @Test func nextDayBoundaryFromExactMidnightAdvancesToNextMidnight() throws {
    // Exactly at 00:00 the boundary is *tomorrow's* 00:00 — otherwise the
    // sleep loop would fire immediately, never sleep, and burn CPU spinning.
    let calendar = Self.utcCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 5, day: 30))
    )
    let next = try #require(HistoryTabView.nextDayBoundary(after: now, calendar: calendar))
    let expected = try #require(
      calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 5, day: 31))
    )
    #expect(next == expected)
  }

  @Test func windowSlidesForwardWhenReferenceAdvancesByOneDay() throws {
    // The acceptance check for #128: the cell set must roll forward when the
    // reference date crosses midnight. Driven through the `init(referenceDate:
    // calendar:)` injection seam via `days(...)` so the assertion doesn't
    // depend on a SwiftUI runtime.
    let calendar = Self.utcCalendar()
    let day1 = reference(2026, 5, 30)
    let day2 = reference(2026, 5, 31)
    let cellsDay1 = HistoryTabView.days(from: [], reference: day1, calendar: calendar)
    let cellsDay2 = HistoryTabView.days(from: [], reference: day2, calendar: calendar)
    let lastDay1 = try #require(cellsDay1.last)
    let lastDay2 = try #require(cellsDay2.last)
    let firstDay1 = try #require(cellsDay1.first)
    let firstDay2 = try #require(cellsDay2.first)
    // Right edge of the window tracks the reference date.
    #expect(calendar.startOfDay(for: lastDay1.date) == calendar.startOfDay(for: day1))
    #expect(calendar.startOfDay(for: lastDay2.date) == calendar.startOfDay(for: day2))
    // And the whole window slides — the oldest cell on day2 is exactly one
    // day after the oldest cell on day1.
    let firstDay1PlusOne = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay1.date))
    #expect(firstDay1PlusOne == firstDay2.date)
  }

  // MARK: - view construction smoke test

  @Test func viewConstructsWithoutCrashingOnEmptyStore() {
    // SwiftData @Query is exercised at view-body time; constructing the view
    // is enough to catch the "predicate failed to compile" or "wrong actor
    // isolation" classes of regression without a snapshot harness.
    _ = HistoryTabView()
    _ = HistoryTabView(referenceDate: reference(2026, 5, 30), calendar: Self.utcCalendar())
  }
}
