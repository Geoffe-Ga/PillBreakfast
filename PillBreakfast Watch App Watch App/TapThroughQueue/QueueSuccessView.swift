import SwiftUI

/// "All pills logged" success state. Auto-dismisses back to the root after a
/// short beat. The hero symbol scales in with `Motion.dramatic` (reserved for
/// celebration states per the design token rules) and the label shimmers once
/// (SPEC §9). Reduce-motion neutralises both effects.
struct QueueSuccessView: View {
  let onDone: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var didAppear = false

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 64, weight: .semibold))
        // Monochrome per the design convention (color is reserved for high-risk).
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
        .scaleEffect(didAppear || reduceMotion ? 1 : 0.6)
        .opacity(didAppear || reduceMotion ? 1 : 0)
      LiquidGlassTheme.Typography.display("All pills logged")
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
        .shimmer()
        .opacity(didAppear || reduceMotion ? 1 : 0)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
    .onAppear {
      if reduceMotion {
        didAppear = true
      } else {
        withAnimation(LiquidGlassTheme.Motion.dramatic) {
          didAppear = true
        }
      }
    }
    .task {
      do {
        try await Task.sleep(for: .seconds(1.5))
      } catch {
        return // task cancelled (view dismissed) — don't navigate
      }
      onDone()
    }
  }
}

#Preview {
  QueueSuccessView(onDone: {})
}
