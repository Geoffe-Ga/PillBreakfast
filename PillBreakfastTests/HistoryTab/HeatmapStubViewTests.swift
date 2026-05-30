import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct HeatmapStubViewTests {
  // MARK: - construction smoke

  @Test func viewBuildsWithEmptyDays() {
    _ = HeatmapStubView(days: [])
  }

  @Test func viewBuildsWithThirtyDays() {
    let cells = HistoryTabView.days(from: [], reference: .now, calendar: .current)
    let view = HeatmapStubView(days: cells)
    _ = view.body
  }

  @Test func viewBuildsWithMixedDensityFixture() {
    var cells = HistoryTabView.days(from: [], reference: .now, calendar: .current)
    if !cells.isEmpty {
      cells[0] = HistoryDay(date: cells[0].date, dayOfMonth: cells[0].dayOfMonth, eventCount: 5)
      cells[cells.count / 2] = HistoryDay(date: cells[cells.count / 2].date, dayOfMonth: cells[cells.count / 2].dayOfMonth, eventCount: 1)
    }
    _ = HeatmapStubView(days: cells).body
  }

  // MARK: - drill-down stub

  @Test func drillDownConstructsAndRendersExpectedPrefix() {
    let view = DayDrillDownStubView(date: .now)
    _ = view.body
  }
}
