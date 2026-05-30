import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct HeatmapViewTests {
  // MARK: - opacity normalization

  @Test func opacityIsZeroBaselineForZeroCount() {
    #expect(HeatmapView.opacity(for: 0, maxCount: 5) == HeatmapView.zeroOpacity)
    // Even with no events anywhere in the window, zero cells still use the
    // baseline rather than tripping the `maxCount > 0` short-circuit.
    #expect(HeatmapView.opacity(for: 0, maxCount: 0) == HeatmapView.zeroOpacity)
  }

  @Test func opacityIsMaxAtMaxCount() {
    let opacityAtMax = HeatmapView.opacity(for: 7, maxCount: 7)
    // Tolerance on the equality — the linear interpolation accumulates a
    // single-ULP rounding error that fails the exact-equality assertion.
    #expect(abs(opacityAtMax - HeatmapView.maxOpacity) < 0.0001)
  }

  @Test func opacityIsMinNonZeroForLowestNonZeroCount() {
    // A day with the smallest possible logged value normalizes to the
    // minimum non-zero opacity — keeps the cell legible against the Liquid
    // Glass surface even when nothing else in the window competes for shade.
    let opacityAtMin = HeatmapView.opacity(for: 1, maxCount: 100)
    let expected = HeatmapView.minNonZeroOpacity
      + (1.0 / 100.0) * (HeatmapView.maxOpacity - HeatmapView.minNonZeroOpacity)
    #expect(abs(opacityAtMin - expected) < 0.0001)
  }

  @Test func opacityIsMonotonicAcrossWindow() {
    let maxCount = 10
    var previous = -1.0
    for count in 1 ... maxCount {
      let opacity = HeatmapView.opacity(for: count, maxCount: maxCount)
      #expect(opacity > previous)
      previous = opacity
    }
  }

  @Test func opacityIsClampedWithinBounds() {
    let opacityAtMin = HeatmapView.opacity(for: 1, maxCount: 100)
    let opacityAtMax = HeatmapView.opacity(for: 100, maxCount: 100)
    #expect(opacityAtMin >= HeatmapView.minNonZeroOpacity)
    #expect(opacityAtMax <= HeatmapView.maxOpacity)
  }

  // MARK: - construction smoke

  @Test func viewBuildsWithEmptyDays() {
    _ = HeatmapView(days: [])
  }

  @Test func viewBuildsWithThirtyDays() {
    let cells = HistoryTabView.days(from: [], reference: .now, calendar: .current)
    let view = HeatmapView(days: cells)
    _ = view.body
  }

  @Test func viewBuildsWithMixedDensityFixture() {
    var cells = HistoryTabView.days(from: [], reference: .now, calendar: .current)
    if !cells.isEmpty {
      cells[0] = HistoryDay(date: cells[0].date, dayOfMonth: cells[0].dayOfMonth, eventCount: 5)
      cells[cells.count / 2] = HistoryDay(
        date: cells[cells.count / 2].date,
        dayOfMonth: cells[cells.count / 2].dayOfMonth,
        eventCount: 1
      )
    }
    _ = HeatmapView(days: cells).body
  }
}
