import SwiftUI

/// Single-tap "Mark Taken" for non-high-risk meds (the EPIC 03 behaviour,
/// extracted so `MarkTakenView` can compose either this or the press-and-hold
/// control). A single tap is fine for vitamins; high-risk meds use
/// `HighRiskConfirmButton` instead.
struct SingleTapConfirmButton: View {
  let onConfirmed: () -> Void

  /// Brief scale dip on press so the confirm reads as a deliberate beat
  /// rather than an instantaneous "did anything happen?" Reduce-motion
  /// neutralises this to a constant scale.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isPressed = false

  var body: some View {
    Button {
      onConfirmed()
    } label: {
      Text("Mark Taken")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
    .buttonStyle(.borderedProminent)
    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.standard))
    .scaleEffect(reduceMotion || !isPressed ? 1 : 0.96)
    .animation(reduceMotion ? nil : LiquidGlassTheme.Motion.snappy, value: isPressed)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
    )
  }
}
