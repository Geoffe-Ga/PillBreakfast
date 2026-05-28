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

extension Color {
  /// Parses a `"#RRGGBB"` hex string; returns nil for nil/malformed input so the
  /// color dot is simply omitted rather than rendered wrong.
  init?(hex: String?) {
    guard let hex else { return nil }
    let trimmed = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
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
