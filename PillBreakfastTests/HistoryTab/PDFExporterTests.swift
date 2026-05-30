import Foundation
import PDFKit
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PDFExporterTests {
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

  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, in calendar: Calendar) throws -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return try #require(calendar.date(from: components))
  }

  @discardableResult
  private func insertDose(
    _ context: ModelContext,
    medication: Medication? = nil,
    ingredientName: String = "Acetaminophen",
    ingredientID: UUID = UUID(),
    mg: Double = 500,
    at takenAt: Date,
    status: DoseStatus = .taken,
    quantity: Int = 1
  ) -> DoseEvent {
    let event = DoseEvent(
      medication: medication,
      takenAt: takenAt,
      quantity: quantity,
      status: status,
      loggedOn: .iphone,
      ingredientAmounts: [LoggedIngredientAmount(
        ingredientID: ingredientID,
        ingredientName: ingredientName,
        totalMg: mg
      )]
    )
    context.insert(event)
    return event
  }

  // MARK: - End-to-end

  @Test func exportProducesNonEmptyPDFForFixture() throws {
    let cal = try utcCalendar()
    let now = try date(2026, 5, 30, in: cal)
    let context = try makeContext()
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    context.insert(lithium)
    let morning30 = try date(2026, 5, 30, 8, 0, in: cal)
    let morning29 = try date(2026, 5, 29, 8, 0, in: cal)
    insertDose(context, medication: lithium, ingredientName: "Lithium Carbonate", mg: 300, at: morning30)
    insertDose(context, medication: lithium, ingredientName: "Lithium Carbonate", mg: 300, at: morning29)
    try context.save()

    let url = try PDFExporter.exportLast30Days(from: context, now: now, calendar: cal)
    defer { try? FileManager.default.removeItem(at: url) }

    // Non-zero size.
    let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
    #expect(size > 0)

    // Parseable PDF with at least one page.
    let document = try #require(PDFDocument(url: url))
    #expect(document.pageCount >= 1)
  }

  // MARK: - Empty window

  @Test func exportProducesSinglePagePDFWithDisclaimerWhenNoDoses() throws {
    let cal = try utcCalendar()
    let now = try date(2026, 5, 30, in: cal)
    let context = try makeContext()

    let url = try PDFExporter.exportLast30Days(from: context, now: now, calendar: cal)
    defer { try? FileManager.default.removeItem(at: url) }

    let document = try #require(PDFDocument(url: url))
    #expect(document.pageCount == 1)

    let text = document.string ?? ""
    // The empty-state header and the seeded disclaimer are both expected.
    #expect(text.contains("No doses logged"))
    #expect(text.contains("starting points only"))
  }

  // MARK: - Structural snapshot

  @Test func exportContainsADayHeaderForEachLoggedDay() throws {
    let cal = try utcCalendar()
    let now = try date(2026, 5, 30, in: cal)
    let context = try makeContext()
    let morning30 = try date(2026, 5, 30, 8, 0, in: cal)
    let morning29 = try date(2026, 5, 29, 8, 0, in: cal)
    let morning28 = try date(2026, 5, 28, 8, 0, in: cal)
    insertDose(context, at: morning30)
    insertDose(context, at: morning29)
    insertDose(context, at: morning28)
    try context.save()

    let url = try PDFExporter.exportLast30Days(from: context, now: now, calendar: cal)
    defer { try? FileManager.default.removeItem(at: url) }

    let document = try #require(PDFDocument(url: url))
    let text = document.string ?? ""
    // Day headers use `Date.formatted(date: .complete)` which renders as
    // "Saturday, May 30, 2026" on a UTC calendar — assert by year-month-day
    // to avoid locale brittleness on the simulator.
    #expect(text.contains("May 30, 2026"))
    #expect(text.contains("May 29, 2026"))
    #expect(text.contains("May 28, 2026"))
  }

  // MARK: - Footer disclaimer

  @Test func exportFooterCarriesSeededIngredientDisclaimer() throws {
    let cal = try utcCalendar()
    let now = try date(2026, 5, 30, in: cal)
    let context = try makeContext()
    let morning = try date(2026, 5, 30, 8, 0, in: cal)
    insertDose(context, at: morning)
    try context.save()

    let url = try PDFExporter.exportLast30Days(from: context, now: now, calendar: cal)
    defer { try? FileManager.default.removeItem(at: url) }

    let document = try #require(PDFDocument(url: url))
    let text = document.string ?? ""
    // Span the disclaimer's distinctive phrases so a copy-edit reflows the
    // text without breaking the assertion on whitespace.
    #expect(text.contains("starting points only"))
    #expect(text.contains("NOT medical advice"))
  }

  // MARK: - Ingredient aggregation

  @Test func aggregateIngredientsSumsTakenAndIgnoresSkippedSnoozed() {
    let id = UUID()
    let events: [DoseEvent] = [
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: id, ingredientName: "Lithium Carbonate", totalMg: 300),
      ]),
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: id, ingredientName: "Lithium Carbonate", totalMg: 300),
      ]),
      DoseEvent(takenAt: .now, quantity: 1, status: .skipped, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: id, ingredientName: "Lithium Carbonate", totalMg: 300),
      ]),
      DoseEvent(takenAt: .now, quantity: 1, status: .snoozed, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: id, ingredientName: "Lithium Carbonate", totalMg: 300),
      ]),
    ]
    let totals = PDFExporter.aggregateIngredients(in: events)
    #expect(totals.count == 1)
    #expect(totals.first?.totalMg == 600)
  }

  @Test func aggregateIngredientsRollsUpSameIngredientAcrossMedications() {
    // Aspirin in a baby-aspirin pill and aspirin in a combo cold med both
    // count toward the same per-ingredient daily total — that's the safety
    // ceiling primitive.
    let aspirinID = UUID()
    let babyAspirin = Medication(displayName: "Bayer 81mg", unitForm: .tablet, kind: .prn)
    let comboCold = Medication(displayName: "Excedrin", unitForm: .tablet, kind: .prn)
    let events: [DoseEvent] = [
      DoseEvent(medication: babyAspirin, takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: aspirinID, ingredientName: "Aspirin", totalMg: 81),
      ]),
      DoseEvent(medication: comboCold, takenAt: .now, quantity: 2, status: .taken, loggedOn: .iphone, ingredientAmounts: [
        LoggedIngredientAmount(ingredientID: aspirinID, ingredientName: "Aspirin", totalMg: 500),
      ]),
    ]
    let totals = PDFExporter.aggregateIngredients(in: events)
    #expect(totals.count == 1)
    #expect(totals.first?.ingredientName == "Aspirin")
    #expect(totals.first?.totalMg == 581)
  }

  @Test func aggregateIngredientsSortsAlphabetically() {
    let lithium = LoggedIngredientAmount(ingredientID: UUID(), ingredientName: "Lithium Carbonate", totalMg: 300)
    let apap = LoggedIngredientAmount(ingredientID: UUID(), ingredientName: "Acetaminophen", totalMg: 500)
    let events: [DoseEvent] = [
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone, ingredientAmounts: [lithium]),
      DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone, ingredientAmounts: [apap]),
    ]
    let totals = PDFExporter.aggregateIngredients(in: events)
    #expect(totals.map(\.ingredientName) == ["Acetaminophen", "Lithium Carbonate"])
  }

  // MARK: - Pagination

  @Test func paginatorEmitsOnePageForFewerBlocksThanFit() {
    let layout = PDFLayoutConstants.letter
    let blocks = (0 ..< 3).map { offset in
      PDFDayBlock(date: Date(timeIntervalSinceReferenceDate: TimeInterval(offset * 86400)), events: [], ingredientTotals: [])
    }
    let pages = PDFPaginator.paginate(blocks, layout: layout)
    #expect(pages.count == 1)
    #expect(pages.first?.count == 3)
  }

  @Test func paginatorBreaksWhenABlockWouldOverflow() {
    // Each block consumes ~300 / 672 ≈ 45 % of the body, so two blocks fit
    // (~600 pt) and three blocks (~900 pt) cannot — exercising the overflow
    // path exactly once.
    let layout = PDFLayoutConstants(
      pageWidth: 612,
      pageHeight: 792,
      margin: 36,
      footerHeight: 48,
      dayHeaderHeight: 300,
      eventRowHeight: 0,
      summaryRowHeight: 0,
      sectionPadding: 0,
      rowIndent: 12,
      footerLineSpacing: 14,
      footerLineHeight: 12
    )
    let blocks = (0 ..< 3).map { offset in
      PDFDayBlock(date: Date(timeIntervalSinceReferenceDate: TimeInterval(offset * 86400)), events: [], ingredientTotals: [])
    }
    let pages = PDFPaginator.paginate(blocks, layout: layout)
    // Each block consumes ≈ half the body, so 3 blocks → exactly 2 pages.
    #expect(pages.count == 2)
    #expect(pages.reduce(0) { $0 + $1.count } == 3)
  }

  @Test func paginatorAllowsOversizedBlockToStandAlone() {
    // A single block taller than the body still lands on its own page rather
    // than disappearing. The next block starts fresh on a new page.
    let layout = PDFLayoutConstants(
      pageWidth: 612,
      pageHeight: 792,
      margin: 36,
      footerHeight: 48,
      dayHeaderHeight: 1000, // intentionally exceeds the page body
      eventRowHeight: 0,
      summaryRowHeight: 0,
      sectionPadding: 0,
      rowIndent: 12,
      footerLineSpacing: 14,
      footerLineHeight: 12
    )
    let blocks = (0 ..< 2).map { offset in
      PDFDayBlock(date: Date(timeIntervalSinceReferenceDate: TimeInterval(offset * 86400)), events: [], ingredientTotals: [])
    }
    let pages = PDFPaginator.paginate(blocks, layout: layout)
    #expect(pages.count == 2)
    #expect(pages.allSatisfy { $0.count == 1 })
  }

  // MARK: - Row formatting

  @Test func eventRowIncludesTimeMedicationQuantityAndStatus() {
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let event = DoseEvent(
      medication: lithium,
      takenAt: Date(timeIntervalSinceReferenceDate: 0),
      quantity: 2,
      status: .taken,
      loggedOn: .iphone
    )
    let row = PDFExporter.eventRow(event)
    #expect(row.contains("Lithium"))
    #expect(row.contains("2 pills"))
    #expect(row.contains("Taken"))
  }

  @Test func eventRowFallsBackToUnknownWhenMedicationIsNil() {
    let event = DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone)
    let row = PDFExporter.eventRow(event)
    #expect(row.contains("Unknown medication"))
  }

  @Test func eventRowSingularPluralPhrasing() {
    // The `quantity == 1 ? "1 pill" : "\(n) pills"` branch deserves its own
    // assertion — both halves matter for an export a doctor reads.
    let single = DoseEvent(takenAt: .now, quantity: 1, status: .taken, loggedOn: .iphone)
    let row = PDFExporter.eventRow(single)
    #expect(row.contains("1 pill"))
    #expect(!row.contains("1 pills"))
  }

  // mg formatting is centralized in `MgFormatter` and covered by
  // `MgFormatterTests`. No per-call-site duplication of those assertions here.
}
