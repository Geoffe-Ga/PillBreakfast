import SwiftUI

/// Single-tap "Mark Taken" for non-high-risk meds (the EPIC 03 behaviour,
/// extracted so `MarkTakenView` can compose either this or the press-and-hold
/// control). A single tap is fine for vitamins; high-risk meds use
/// `HighRiskConfirmButton` instead.
struct SingleTapConfirmButton: View {
  let onConfirmed: () -> Void

  var body: some View {
    Button {
      onConfirmed()
    } label: {
      Text("Mark Taken")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
    .buttonStyle(SnappyProminentButtonStyle())
  }
}

/// Bordered-prominent appearance with a brief scale dip on press, driven by
/// `configuration.isPressed` (not a `DragGesture`) so digital-crown scrolls
/// and swipe-to-dismiss can't leave the button stuck in the pressed state.
/// Reduce-motion neutralises the scale.
private struct SnappyProminentButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .background(.tint)
      .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.standard))
      .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
      .animation(reduceMotion ? nil : LiquidGlassTheme.Motion.snappy, value: configuration.isPressed)
  }
}
