import SwiftUI
import WatchKit

/// Press-and-hold confirmation for high-risk meds (SPEC §2.1, §9). The user must
/// hold for `holdDuration` while an amber Liquid Glass ring fills; lifting early
/// animates the ring back and logs nothing. There is deliberately no tap-to-skip
/// the hold — that bypass is the exact regression this guards against.
struct HighRiskConfirmButton: View {
  let holdDuration: TimeInterval
  let hint: String
  let onConfirmed: () -> Void

  @State private var hold: HoldProgress
  @State private var checkpointTask: Task<Void, Never>?
  /// One-shot guard so completion (which can be signalled by both the long-press
  /// end and the finger-lift) fires `onConfirmed` exactly once.
  @State private var didConfirm = false

  init(holdDuration: TimeInterval = 0.5, hint: String = "Hold to confirm", onConfirmed: @escaping () -> Void) {
    self.holdDuration = holdDuration
    self.hint = hint
    self.onConfirmed = onConfirmed
    _hold = State(initialValue: HoldProgress(holdDuration: holdDuration))
  }

  var body: some View {
    ZStack {
      ring
      Text(hint)
        .font(LiquidGlassTheme.Typography.captionFont)
        .foregroundStyle(LiquidGlassTheme.Colors.highRiskAccent)
        .multilineTextAlignment(.center)
    }
    .frame(width: 120, height: 120)
    .contentShape(Circle())
    .gesture(
      LongPressGesture(minimumDuration: holdDuration)
        .onEnded { _ in completeHold() }
        .simultaneously(
          with:
          DragGesture(minimumDistance: 0)
            .onChanged { _ in beginHoldIfNeeded() }
            .onEnded { _ in liftFinger() }
        )
    )
    .accessibilityLabel(hint)
    .accessibilityAddTraits(.isButton)
    // VoiceOver can't drive a `LongPressGesture`, so the press-and-hold ring
    // is unreachable for assistive-tech users without an alternate path.
    // The action lives on the rotor (not on the default double-tap) so the
    // 2-step safety pattern survives: the user must intentionally select
    // "Confirm dose" from the rotor rather than fire it from a stray tap.
    .accessibilityAction(named: "Confirm dose") { confirmOnce() }
    .onDisappear {
      // Stop the haptic checkpoints if the screen goes away mid-hold, so clicks
      // don't fire after the view is gone.
      checkpointTask?.cancel()
      hold.reset()
    }
  }

  private var ring: some View {
    // Paused while not holding so an idle confirmation screen isn't animating
    // every frame on a battery-constrained device.
    TimelineView(.animation(paused: !hold.isHolding)) { timeline in
      ZStack {
        Circle()
          .stroke(LiquidGlassTheme.Colors.secondaryText.opacity(0.25), lineWidth: 6)
        Circle()
          .trim(from: 0, to: hold.progress(at: timeline.date))
          .stroke(
            LiquidGlassTheme.Colors.highRiskAccent,
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          // Animate the ring emptying when a hold is cancelled.
          .animation(.easeOut(duration: 0.2), value: hold.state)
      }
    }
  }

  private func beginHoldIfNeeded() {
    guard !hold.isHolding, hold.state != .completed else { return }
    hold.begin(at: .now)
    // Reset the one-shot guard only once a fresh hold has actually started.
    didConfirm = false
    scheduleCheckpointHaptics()
  }

  private func completeHold() {
    checkpointTask?.cancel()
    hold.complete()
    confirmOnce()
  }

  private func liftFinger() {
    checkpointTask?.cancel()
    let wasCompleted = hold.state == .completed
    hold.release(at: .now)
    switch hold.state {
    case .completed where !wasCompleted:
      confirmOnce()
    case .cancelled:
      WKInterfaceDevice.current().play(.failure)
      hold.reset()
    default:
      break
    }
  }

  private func confirmOnce() {
    guard !didConfirm else { return }
    didConfirm = true
    WKInterfaceDevice.current().play(.success)
    onConfirmed()
  }

  /// Light haptic at 25/50/75% of the hold, cancelled the moment the finger lifts.
  private func scheduleCheckpointHaptics() {
    checkpointTask?.cancel()
    checkpointTask = Task { @MainActor in
      let start = Date.now
      for fraction in [0.25, 0.5, 0.75] {
        let remaining = holdDuration * fraction - Date.now.timeIntervalSince(start)
        if remaining > 0 {
          do {
            try await Task.sleep(for: .seconds(remaining))
          } catch {
            return // cancelled by an early release
          }
        }
        if Task.isCancelled { return }
        WKInterfaceDevice.current().play(.click)
      }
    }
  }
}
