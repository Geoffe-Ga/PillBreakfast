import Foundation
import os
@testable import PillBreakfast_Watch_App_Watch_App
import Testing

/// Debounce behaviour for the widget-reload coordinator, exercised through the
/// `onReload` seam (the real `WidgetCenter` singleton is unmockable). Intervals
/// are short but with generous sleep margins to stay deterministic.
struct WidgetReloadCoordinatorTests {
  private let debounce: TimeInterval = 0.1

  @Test func twoCallsWithinWindowFireOnce() async throws {
    let counter = OSAllocatedUnfairLock(initialState: 0)
    let coordinator = WidgetReloadCoordinator(debounceSecs: debounce) {
      counter.withLock { $0 += 1 }
    }
    await coordinator.scheduleReload()
    await coordinator.scheduleReload()
    try await Task.sleep(nanoseconds: UInt64(debounce * 3 * 1_000_000_000))
    #expect(counter.withLock { $0 } == 1)
  }

  @Test func singleCallFiresOnce() async throws {
    let counter = OSAllocatedUnfairLock(initialState: 0)
    let coordinator = WidgetReloadCoordinator(debounceSecs: debounce) {
      counter.withLock { $0 += 1 }
    }
    await coordinator.scheduleReload()
    try await Task.sleep(nanoseconds: UInt64(debounce * 3 * 1_000_000_000))
    #expect(counter.withLock { $0 } == 1)
  }

  @Test func callsFarApartFireTwice() async throws {
    let counter = OSAllocatedUnfairLock(initialState: 0)
    let coordinator = WidgetReloadCoordinator(debounceSecs: debounce) {
      counter.withLock { $0 += 1 }
    }
    await coordinator.scheduleReload()
    try await Task.sleep(nanoseconds: UInt64(debounce * 3 * 1_000_000_000))
    await coordinator.scheduleReload()
    try await Task.sleep(nanoseconds: UInt64(debounce * 3 * 1_000_000_000))
    #expect(counter.withLock { $0 } == 2)
  }

  @Test func reloadNowFiresImmediatelyAndCancelsPending() async throws {
    let counter = OSAllocatedUnfairLock(initialState: 0)
    let coordinator = WidgetReloadCoordinator(debounceSecs: debounce) {
      counter.withLock { $0 += 1 }
    }
    await coordinator.scheduleReload() // would fire later…
    await coordinator.reloadNow() // …but this fires now and cancels it
    #expect(counter.withLock { $0 } == 1)
    try await Task.sleep(nanoseconds: UInt64(debounce * 3 * 1_000_000_000))
    #expect(counter.withLock { $0 } == 1) // the cancelled scheduled one never fired
  }
}
