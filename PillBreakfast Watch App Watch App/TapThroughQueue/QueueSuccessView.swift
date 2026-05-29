import SwiftUI

/// "All pills logged" success state. Auto-dismisses back to the root after a
/// short beat, with a one-shot Liquid Glass shimmer across the label (SPEC §9).
struct QueueSuccessView: View {
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.compact) {
      Image(systemName: "checkmark.circle.fill")
        // Monochrome per the design convention (color is reserved for high-risk).
        .font(.largeTitle)
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
      LiquidGlassTheme.Typography.title("All pills logged")
        .shimmer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
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
