import SwiftUI

/// Brief "Pill Breakfast logged ✓" micro-state shown between meals once the
/// user has confirmed the last dose of one. The view auto-advances after
/// `Self.dwellSeconds` by calling `onAdvance` so the queue knows when to
/// continue. Reduce-motion suppresses the `Motion.dramatic` reveal.
struct MealCompletionView: View {
  let mealName: String
  let onAdvance: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible = false

  /// 0.5 s reads as a beat between meals — long enough to confirm the win,
  /// short enough that the user isn't waiting on the next card.
  static let dwellSeconds: Double = 0.5

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
      LiquidGlassTheme.Typography.display("\(mealName) logged")
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
    .opacity(visible ? 1 : 0)
    .scaleEffect(visible ? 1 : 0.85)
    // SwiftUI does not auto-skip custom Animation values under reduce-motion;
    // gate explicitly per the existing pattern in RightNowView.
    .animation(reduceMotion ? nil : LiquidGlassTheme.Motion.dramatic, value: visible)
    .task {
      visible = true
      try? await Task.sleep(for: .seconds(Self.dwellSeconds))
      onAdvance()
    }
  }
}

#Preview {
  MealCompletionView(mealName: "Pill Breakfast", onAdvance: {})
}
