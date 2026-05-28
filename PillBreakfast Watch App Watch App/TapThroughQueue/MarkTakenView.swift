import SwiftUI

/// One pill per screen. Single-tap "Mark Taken" for now; the high-risk
/// press-and-hold gesture lands in EPIC 04. A secondary "Skip" logs a skipped
/// dose. ("Snooze until…" is intentionally omitted here — it arrives in EPIC 06.)
struct MarkTakenView: View {
  let medicationName: String
  let detail: String
  let colorHex: String?
  let onMarkTaken: () -> Void
  let onSkip: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        if let color = Color(hex: colorHex) {
          Circle().fill(color).frame(width: 10, height: 10)
        }
        Text(medicationName)
          .font(.headline)
          .multilineTextAlignment(.center)
      }

      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)

      Button("Mark Taken", action: onMarkTaken)
        .buttonStyle(.borderedProminent)

      Button("Skip", action: onSkip)
        .buttonStyle(.bordered)
        .font(.caption)
    }
    .padding()
  }
}

#Preview {
  MarkTakenView(
    medicationName: "Vitamin D",
    detail: "2000mg · 1 tablet",
    colorHex: "#FFAA00",
    onMarkTaken: {},
    onSkip: {}
  )
}
