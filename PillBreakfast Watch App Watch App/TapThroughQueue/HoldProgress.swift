import Foundation

/// Pure state machine behind the high-risk press-and-hold confirmation.
///
/// Deterministic and UI-free so it can be unit-tested without driving a real
/// gesture: the caller supplies `now` at each transition. The SwiftUI gesture
/// layer (`HighRiskConfirmButton`) maps touch events onto `begin` / `complete`
/// / `release` and reads `progress(at:)` to fill the ring.
@MainActor
@Observable
final class HoldProgress {
  enum State: Equatable {
    case idle
    case holding(startedAt: Date)
    case completed
    case cancelled
  }

  private(set) var state: State = .idle
  let holdDuration: TimeInterval

  init(holdDuration: TimeInterval) {
    self.holdDuration = holdDuration
  }

  var isHolding: Bool {
    if case .holding = state { return true }
    return false
  }

  /// Begins a hold from rest. Guarded to `.idle`/`.cancelled` so it can never
  /// overwrite a `.completed` hold (which would re-fire confirmation) or restart
  /// an in-flight `.holding` clock — the invariant is enforced here, not trusted
  /// to the caller, because this gates a safety-critical confirmation.
  func begin(at now: Date) {
    guard state == .idle || state == .cancelled else { return }
    state = .holding(startedAt: now)
  }

  /// Completes the hold unconditionally from `.holding`. Driven by the long-press
  /// gesture firing at `minimumDuration` — we trust the gesture's own clock here
  /// rather than re-deriving elapsed time (sub-millisecond skew must not flip a
  /// genuine completion into a cancel).
  func complete() {
    guard case .holding = state else { return }
    state = .completed
  }

  /// Resolves a finger-lift: completed if held at least `holdDuration`, else
  /// cancelled. No-ops once `.completed`, so a lift after completion can't undo it.
  func release(at now: Date) {
    guard case let .holding(startedAt) = state else { return }
    state = now.timeIntervalSince(startedAt) >= holdDuration ? .completed : .cancelled
  }

  func reset() {
    state = .idle
  }

  /// Ring fill in `0...1`. Climbs linearly while holding; 1 once completed; 0
  /// when idle or cancelled.
  func progress(at now: Date) -> Double {
    switch state {
    case let .holding(startedAt):
      min(1, max(0, now.timeIntervalSince(startedAt) / holdDuration))
    case .completed:
      1
    case .idle, .cancelled:
      0
    }
  }
}
