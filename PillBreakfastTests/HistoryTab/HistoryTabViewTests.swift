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

  private func insertEvent(at takenAt: Date, into context: ModelContext) {
    context.insert(DoseEvent(
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
    #expect(cells.count == 30)
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

  @Test func daysIgnoreEventsOutsideTheWindow() throws {
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
    // Only the in-window May 15 event is counted; the April 1 one is silently
    // dropped because no cell's day-start matches it.
    #expect(total == 1)
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
