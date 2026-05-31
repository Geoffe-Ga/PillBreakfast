import SwiftUI

/// "All pills logged" success state. Auto-dismisses back to the root after a
/// short beat. The hero symbol scales in with `Motion.dramatic` (reserved for
/// celebration states per the design token rules) and the label shimmers once
/// (SPEC §9). Reduce-motion neutralises both effects.
struct QueueSuccessView: View {
  let onDone: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var didAppear = false
  /// Gated separately from `didAppear` so the shimmer doesn't sweep while the
  /// label is still faded out — `.shimmer()` fires on view attach, but the
  /// label is invisible until the `Motion.dramatic` reveal completes.
  @State private var shimmerArmed = false

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 64, weight: .semibold))
        // Monochrome per the design convention (color is reserved for high-risk).
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
        .scaleEffect(didAppear || reduceMotion ? 1 : 0.6)
        .opacity(didAppear || reduceMotion ? 1 : 0)
      Group {
        if shimmerArmed {
          LiquidGlassTheme.Typography.display("All pills logged")
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .shimmer()
        } else {
          LiquidGlassTheme.Typography.display("All pills logged")
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
        }
      }
      .opacity(didAppear || reduceMotion ? 1 : 0)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
    .onAppear {
      withAnimation(reduceMotion ? nil : LiquidGlassTheme.Motion.dramatic) {
        didAppear = true
      }
    }
    .task {
      // Wait until after the `Motion.dramatic` reveal lands before arming the
      // shimmer so it sweeps across a *visible* label. Under reduce-motion
      // the label is visible from the first frame and the shimmer is
      // suppressed by `Group`'s identity change but is also harmless.
      do {
        try await Task.sleep(for: .seconds(0.5))
      } catch {
        return
      }
      shimmerArmed = true
      do {
        try await Task.sleep(for: .seconds(1.0))
      } catch {
        return
      }
      onDone()
    }
  }
}

#Preview {
  QueueSuccessView(onDone: {})
}
