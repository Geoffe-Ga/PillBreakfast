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

  // MARK: - mg formatting

  @Test func formatMgRoundsToWholeMilligrams() {
    #expect(DayDrillDownView.formatMg(0) == "0 mg")
    #expect(DayDrillDownView.formatMg(200) == "200 mg")
    #expect(DayDrillDownView.formatMg(199.4) == "199 mg")
    #expect(DayDrillDownView.formatMg(199.6) == "200 mg")
    // Lithium daily ceiling — the call-site precision target.
    #expect(DayDrillDownView.formatMg(2400) == "2400 mg")
  }

  @Test func formatMgRendersDashForNonFiniteInputs() {
    // `Int(Double.nan)` and `Int(Double.infinity)` would trap; the guard
    // turns them into a legible placeholder instead.
    #expect(DayDrillDownView.formatMg(.nan) == "— mg")
    #expect(DayDrillDownView.formatMg(.infinity) == "— mg")
    #expect(DayDrillDownView.formatMg(-.infinity) == "— mg")
  }
}
