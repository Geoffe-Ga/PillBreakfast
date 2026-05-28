import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct HoldProgressTests {
  private let t0 = Date(timeIntervalSince1970: 1_000_000)
  private let duration: TimeInterval = 0.5

  private func makeHolding() -> HoldProgress {
    let hold = HoldProgress(holdDuration: duration)
    hold.begin(at: t0)
    return hold
  }

  @Test func startsIdleWithZeroProgress() {
    let hold = HoldProgress(holdDuration: duration)
    #expect(hold.state == .idle)
    #expect(hold.progress(at: t0) == 0)
    #expect(hold.isHolding == false)
  }

  @Test func progressClimbsLinearlyWhileHolding() {
    let hold = makeHolding()
    #expect(hold.isHolding)
    #expect(hold.progress(at: t0) == 0)
    #expect(hold.progress(at: t0.addingTimeInterval(0.25)) == 0.5)
    #expect(hold.progress(at: t0.addingTimeInterval(0.5)) == 1)
  }

  @Test func progressReachesOneOnlyAfterDuration() {
    let hold = makeHolding()
    // Just shy of the duration is still < 1.
    #expect(hold.progress(at: t0.addingTimeInterval(0.49)) < 1)
    // At and beyond the duration it clamps to 1.
    #expect(hold.progress(at: t0.addingTimeInterval(0.5)) == 1)
    #expect(hold.progress(at: t0.addingTimeInterval(2)) == 1)
  }

  @Test func releaseBeforeDurationCancelsWithZeroProgress() {
    let hold = makeHolding()
    hold.release(at: t0.addingTimeInterval(0.3))
    #expect(hold.state == .cancelled)
    #expect(hold.progress(at: t0.addingTimeInterval(0.3)) == 0)
  }

  @Test func releaseAfterDurationCompletes() {
    let hold = makeHolding()
    hold.release(at: t0.addingTimeInterval(0.6))
    #expect(hold.state == .completed)
    #expect(hold.progress(at: t0.addingTimeInterval(0.6)) == 1)
  }

  @Test func completeFromHoldingCompletes() {
    let hold = makeHolding()
    hold.complete()
    #expect(hold.state == .completed)
    #expect(hold.progress(at: t0) == 1)
  }

  @Test func completeIgnoredWhenNotHolding() {
    let hold = HoldProgress(holdDuration: duration)
    hold.complete()
    #expect(hold.state == .idle)
  }

  @Test func releaseAfterCompletedIsNoop() {
    let hold = makeHolding()
    hold.complete()
    // A finger-lift after the long-press already completed must not flip it.
    hold.release(at: t0.addingTimeInterval(0.1))
    #expect(hold.state == .completed)
  }

  @Test func resetReturnsToIdle() {
    let hold = makeHolding()
    hold.complete()
    hold.reset()
    #expect(hold.state == .idle)
    #expect(hold.progress(at: t0) == 0)
  }

  @Test func beginAfterCancelRestartsClock() {
    let hold = makeHolding()
    hold.release(at: t0.addingTimeInterval(0.1)) // cancelled
    let t1 = t0.addingTimeInterval(5)
    hold.begin(at: t1)
    #expect(hold.isHolding)
    #expect(hold.progress(at: t1) == 0)
    #expect(hold.progress(at: t1.addingTimeInterval(0.5)) == 1)
  }
}
