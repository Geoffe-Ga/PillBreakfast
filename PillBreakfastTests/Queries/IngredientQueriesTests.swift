import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct IngredientQueriesTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func calendar(_ tzIdentifier: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: tzIdentifier))
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

  /// Inserts a `DoseEvent` carrying only an `ingredientAmounts` snapshot — no
  /// medication/components — so the tests also prove the queries read the frozen
  /// snapshot rather than the live product graph.
  @discardableResult
  private func insertDose(
    _ context: ModelContext,
    ingredientID: UUID,
    mg: Double,
    at takenAt: Date,
    status: DoseStatus = .taken
  ) -> DoseEvent {
    let event = DoseEvent(
      takenAt: takenAt,
      quantity: 1,
      status: status,
      loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: ingredientID, ingredientName: "Acetaminophen", totalMg: mg)]
    )
    context.insert(event)
    return event
  }

  // MARK: - totalToday

  @Test func totalTodaySumsSingleProduct() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 9, 0, in: cal))

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 1000)
  }

  @Test func totalTodaySumsAcrossMultipleProducts() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    // Tylenol + Excedrin both contribute acetaminophen.
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 9, 0, in: cal))
    try insertDose(context, ingredientID: apap.id, mg: 500, at: date(2026, 5, 29, 11, 0, in: cal))

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 1500)
  }

  @Test func totalTodayIgnoresSkippedAndSnoozed() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 8, 0, in: cal), status: .taken)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 9, 0, in: cal), status: .skipped)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 10, 0, in: cal), status: .snoozed)

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 1000)
  }

  @Test func totalTodayExcludesYesterday() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 999, at: date(2026, 5, 28, 23, 0, in: cal)) // yesterday
    try insertDose(context, ingredientID: apap.id, mg: 250, at: date(2026, 5, 29, 0, 30, in: cal)) // today

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 250)
  }

  @Test func totalTodayExcludesFutureWithinToday() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 300, at: date(2026, 5, 29, 10, 0, in: cal)) // before now
    try insertDose(context, ingredientID: apap.id, mg: 700, at: date(2026, 5, 29, 14, 0, in: cal)) // after now

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 300)
  }

  @Test func totalTodayHonoursInjectedCalendarDayBoundary() throws {
    let utc = try calendar("UTC")
    let eastern = try calendar("America/New_York")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    // Same absolute instants. The 02:00-UTC dose is "today" in UTC (day starts
    // 00:00 UTC) but "yesterday" in Eastern, whose 2026-05-29 day starts at
    // 04:00 UTC — so 02:00 UTC falls in the previous Eastern day.
    let now = try date(2026, 5, 29, 12, 0, in: utc)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 2, 0, in: utc))

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: utc) == 1000)
    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: eastern) == 0)
  }

  @Test func totalTodayIgnoresOtherIngredients() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let ibuprofen = Ingredient(name: "Ibuprofen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 1000, at: date(2026, 5, 29, 9, 0, in: cal))
    try insertDose(context, ingredientID: ibuprofen.id, mg: 400, at: date(2026, 5, 29, 10, 0, in: cal))

    #expect(try IngredientQueries.totalToday(ingredient: apap, in: context, at: now, calendar: cal) == 1000)
  }

  // MARK: - lastDoseTime

  @Test func lastDoseTimeReturnsMostRecentTakenDose() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    try insertDose(context, ingredientID: apap.id, mg: 500, at: date(2026, 5, 29, 8, 0, in: cal))
    let latest = try date(2026, 5, 29, 10, 0, in: cal)
    insertDose(context, ingredientID: apap.id, mg: 500, at: latest)

    #expect(try IngredientQueries.lastDoseTime(ingredient: apap, in: context, atOrBefore: now) == latest)
  }

  @Test func lastDoseTimeIgnoresSkippedAndFutureAndOtherIngredients() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let ibuprofen = Ingredient(name: "Ibuprofen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)
    let taken = try date(2026, 5, 29, 7, 0, in: cal)
    insertDose(context, ingredientID: apap.id, mg: 500, at: taken, status: .taken)
    try insertDose(context, ingredientID: apap.id, mg: 500, at: date(2026, 5, 29, 9, 0, in: cal), status: .skipped)
    try insertDose(context, ingredientID: ibuprofen.id, mg: 400, at: date(2026, 5, 29, 10, 0, in: cal), status: .taken)
    try insertDose(context, ingredientID: apap.id, mg: 500, at: date(2026, 5, 29, 14, 0, in: cal), status: .taken) // future

    #expect(try IngredientQueries.lastDoseTime(ingredient: apap, in: context, atOrBefore: now) == taken)
  }

  // MARK: - lastProductDoseTime

  @Test func lastProductDoseTimeIsPerProductNotPerIngredient() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let tylenol = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    let excedrin = Medication(displayName: "Excedrin", unitForm: .tablet, kind: .prn)
    context.insert(tylenol)
    context.insert(excedrin)

    let tylenolTime = try date(2026, 5, 29, 8, 0, in: cal)
    let excedrinTime = try date(2026, 5, 29, 10, 0, in: cal) // more recent, shares acetaminophen
    context.insert(DoseEvent(
      medication: tylenol, takenAt: tylenolTime, quantity: 1, status: .taken, loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: apap.id, ingredientName: "Acetaminophen", totalMg: 500)]
    ))
    context.insert(DoseEvent(
      medication: excedrin, takenAt: excedrinTime, quantity: 1, status: .taken, loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: apap.id, ingredientName: "Acetaminophen", totalMg: 250)]
    ))
    try context.save()

    let now = try date(2026, 5, 29, 12, 0, in: cal)
    // Per product: Tylenol's last dose is its own, not Excedrin's (more recent, same ingredient).
    #expect(try IngredientQueries.lastProductDoseTime(medication: tylenol, in: context, atOrBefore: now) == tylenolTime)
    #expect(try IngredientQueries.lastProductDoseTime(medication: excedrin, in: context, atOrBefore: now) == excedrinTime)
  }

  @Test func lastProductDoseTimeIsNilWhenProductNeverTaken() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let tylenol = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    context.insert(tylenol)
    try context.save()

    #expect(try IngredientQueries.lastProductDoseTime(medication: tylenol, in: context, atOrBefore: date(2026, 5, 29, 12, 0, in: cal)) == nil)
  }

  @Test func lastDoseTimeIsNilWhenNoMatchingDose() throws {
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)

    #expect(try IngredientQueries.lastDoseTime(ingredient: apap, in: context, atOrBefore: now) == nil)
  }

  @Test func lastDoseTimeFindsMatchBeyondFirstPage() throws {
    // Bounded-scan regression: seed `pageSize + 50` non-matching events with
    // takenAt newer than the single matching dose, then assert the match is
    // still returned. A naive `fetchLimit = pageSize` without paging would
    // return `nil` here.
    let cal = try calendar("UTC")
    let context = try makeContext()
    let apap = Ingredient(name: "Acetaminophen")
    let ibu = Ingredient(name: "Ibuprofen")
    let now = try date(2026, 5, 29, 12, 0, in: cal)

    // The needle: one apap dose, far back relative to the noise.
    let needleTaken = try date(2026, 5, 28, 8, 0, in: cal)
    insertDose(context, ingredientID: apap.id, mg: 500, at: needleTaken)

    // The haystack: `pageSize + 50` ibuprofen doses with takenAt strictly
    // newer than the needle so they sort ahead of it in descending order.
    let haystackCount = IngredientQueries.pageSize + 50
    let baseHaystack = try date(2026, 5, 28, 9, 0, in: cal) // 1h after needle
    for offset in 0 ..< haystackCount {
      let takenAt = try #require(cal.date(byAdding: .second, value: offset, to: baseHaystack))
      insertDose(context, ingredientID: ibu.id, mg: 200, at: takenAt)
    }
    try context.save()

    #expect(try IngredientQueries.lastDoseTime(ingredient: apap, in: context, atOrBefore: now) == needleTaken)
  }
}
