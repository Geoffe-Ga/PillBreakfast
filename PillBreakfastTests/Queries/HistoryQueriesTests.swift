import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct HistoryQueriesTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func utcCalendar() throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
    return calendar
  }

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, in calendar: Calendar) throws -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return try #require(calendar.date(from: components))
  }

  /// Inserts a `DoseEvent` carrying an `ingredientAmounts` snapshot — matches
  /// the pattern in `IngredientQueriesTests` so the query is exercised against
  /// the frozen denormalized snapshot, not a live product graph.
  @discardableResult
  private func insertDose(
    _ context: ModelContext,
    name: String,
    ingredientID: UUID,
    mg: Double,
    at takenAt: Date,
    status: DoseStatus = .taken,
    quantity: Int = 1
  ) -> DoseEvent {
    let event = DoseEvent(
      takenAt: takenAt,
      quantity: quantity,
      status: status,
      loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(
        ingredientID: ingredientID,
        ingredientName: name,
        totalMg: mg
      )]
    )
    context.insert(event)
    return event
  }

  // MARK: - empty day

  @Test func dailySummaryIsEmptyForADayWithNoEvents() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let day = try date(2026, 5, 29, 12, 0, in: cal)
    let summary = try HistoryQueries.dailySummary(in: context, day: day, calendar: cal)
    #expect(summary.totalCount == 0)
    #expect(summary.takenCount == 0)
    #expect(summary.skippedCount == 0)
    #expect(summary.snoozedCount == 0)
    #expect(summary.ingredientTotals.isEmpty)
    // `day` is normalized to the start of the calendar day.
    #expect(summary.day == cal.startOfDay(for: day))
  }

  // MARK: - single-product day

  @Test func dailySummaryAggregatesSingleProductDay() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let apapID = UUID()
    let morning = try date(2026, 5, 29, 8, 0, in: cal)
    let evening = try date(2026, 5, 29, 20, 0, in: cal)
    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: morning)
    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: evening)
    try context.save()

    let summary = try HistoryQueries.dailySummary(in: context, day: morning, calendar: cal)
    #expect(summary.totalCount == 2)
    #expect(summary.takenCount == 2)
    #expect(summary.ingredientTotals.count == 1)
    let total = try #require(summary.ingredientTotals.first)
    #expect(total.ingredientName == "Acetaminophen")
    #expect(total.totalMg == 1000)
  }

  // MARK: - multi-product day

  @Test func dailySummaryAggregatesAcrossMultipleIngredients() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let apapID = UUID()
    let ibuID = UUID()
    let morning = try date(2026, 5, 29, 8, 0, in: cal)
    let noon = try date(2026, 5, 29, 12, 0, in: cal)
    let evening = try date(2026, 5, 29, 20, 0, in: cal)

    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: morning)
    insertDose(context, name: "Ibuprofen", ingredientID: ibuID, mg: 200, at: noon)
    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: evening)
    try context.save()

    let summary = try HistoryQueries.dailySummary(in: context, day: morning, calendar: cal)
    #expect(summary.totalCount == 3)
    #expect(summary.ingredientTotals.count == 2)
    // Sorted alphabetically by ingredient name.
    #expect(summary.ingredientTotals.map(\.ingredientName) == ["Acetaminophen", "Ibuprofen"])
    #expect(summary.ingredientTotals[0].totalMg == 1000)
    #expect(summary.ingredientTotals[1].totalMg == 200)
  }

  // MARK: - mixed-status day

  @Test func dailySummaryCountsStatusButOnlyTakenContributesToTotals() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let apapID = UUID()
    let day = try date(2026, 5, 29, 12, 0, in: cal)
    let morning = try date(2026, 5, 29, 8, 0, in: cal)
    let noon = try date(2026, 5, 29, 12, 0, in: cal)
    let evening = try date(2026, 5, 29, 20, 0, in: cal)

    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: morning, status: .taken)
    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: noon, status: .skipped)
    insertDose(context, name: "Acetaminophen", ingredientID: apapID, mg: 500, at: evening, status: .snoozed)
    try context.save()

    let summary = try HistoryQueries.dailySummary(in: context, day: day, calendar: cal)
    // All three statuses count toward the per-status totals.
    #expect(summary.totalCount == 3)
    #expect(summary.takenCount == 1)
    #expect(summary.skippedCount == 1)
    #expect(summary.snoozedCount == 1)
    // But only the `.taken` event contributes to the ingredient total —
    // `.skipped` and `.snoozed` doses never reached the body.
    #expect(summary.ingredientTotals.count == 1)
    #expect(summary.ingredientTotals.first?.totalMg == 500)
  }

  // MARK: - window boundaries

  @Test func dailySummaryIsScopedToTheCalendarDay() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let apapID = UUID()
    let target = try date(2026, 5, 29, 12, 0, in: cal)
    // The day before, at 23:59 — out of window.
    let dayBefore = try date(2026, 5, 28, 23, 59, in: cal)
    // The day after, at 00:00 — out of window (end is exclusive).
    let dayAfter = try date(2026, 5, 30, 0, 0, in: cal)
    // Inside the window: the start of day and the last minute.
    let inWindowStart = try date(2026, 5, 29, 0, 0, in: cal)
    let inWindowEnd = try date(2026, 5, 29, 23, 59, in: cal)

    insertDose(context, name: "A", ingredientID: apapID, mg: 1, at: dayBefore)
    insertDose(context, name: "A", ingredientID: apapID, mg: 10, at: inWindowStart)
    insertDose(context, name: "A", ingredientID: apapID, mg: 100, at: inWindowEnd)
    insertDose(context, name: "A", ingredientID: apapID, mg: 1000, at: dayAfter)
    try context.save()

    let summary = try HistoryQueries.dailySummary(in: context, day: target, calendar: cal)
    #expect(summary.totalCount == 2)
    #expect(summary.ingredientTotals.first?.totalMg == 110)
  }

  // MARK: - day normalization

  @Test func dailySummaryNormalizesDayToStartOfCalendarDay() throws {
    let cal = try utcCalendar()
    let context = try makeContext()
    let lateAfternoon = try date(2026, 5, 29, 17, 0, in: cal)

    let summary = try HistoryQueries.dailySummary(in: context, day: lateAfternoon, calendar: cal)
    let expectedDay = cal.startOfDay(for: lateAfternoon)
    #expect(summary.day == expectedDay)
  }
}
