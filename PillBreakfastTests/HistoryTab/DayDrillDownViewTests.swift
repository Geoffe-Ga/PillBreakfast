import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct DayDrillDownViewTests {
  // MARK: - construction smoke

  @Test func viewConstructsWithDefaultCalendar() {
    _ = DayDrillDownView(date: .now)
  }

  @Test func viewConstructsWithInjectedCalendar() {
    var calendar = Calendar(identifier: .gregorian)
    if let utc = TimeZone(identifier: "UTC") {
      calendar.timeZone = utc
    }
    _ = DayDrillDownView(date: .now, calendar: calendar)
  }

  @Test func viewConstructsWithFilterMedicationID() {
    // `nil` and a concrete UUID must both compile through the @Query
    // predicate's optional comparison.
    _ = DayDrillDownView(date: .now, filterMedicationID: nil)
    _ = DayDrillDownView(date: .now, filterMedicationID: UUID())
  }

  // MARK: - mg formatting

  // mg formatting is centralized in `MgFormatter` and covered by
  // `MgFormatterTests`. The drill-down's "Ingredient totals" section now
  // reads from the same source as the PDF export.
}
