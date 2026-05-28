import SwiftUI

/// "All pills logged" success state. Auto-dismisses back to the root after a
/// short beat. The Liquid Glass success shimmer lands in EPIC 04.
struct QueueSuccessView: View {
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .font(.largeTitle)
        // Monochrome per the design convention (color is reserved for high-risk);
        // the Liquid Glass success shimmer lands in EPIC 04.
        .foregroundStyle(.primary)
      Text("All pills logged")
        .font(.headline)
    }
    .padding()
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
