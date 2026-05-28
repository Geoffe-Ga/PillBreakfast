import SwiftUI

/// One pill per screen. Non-high-risk meds confirm with a single tap; high-risk
/// meds require the press-and-hold ring (`HighRiskConfirmButton`) — single-tap on
/// a high-risk dose is the regression this guards against. A secondary "Skip"
/// logs a skipped dose. ("Snooze until…" is intentionally omitted — it's EPIC 06.)
struct MarkTakenView: View {
  let medicationName: String
  let detail: String
  let isHighRisk: Bool
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

      if isHighRisk {
        HighRiskConfirmButton(onConfirmed: onMarkTaken)
      } else {
        SingleTapConfirmButton(onConfirmed: onMarkTaken)
      }

      Button("Skip", action: onSkip)
        .buttonStyle(.bordered)
        .font(.caption)
    }
    .padding()
  }
}

#Preview("High-risk (hold)") {
  MarkTakenView(
    medicationName: "Lithium 300mg",
    detail: "300mg · 1 tablet",
    isHighRisk: true,
    colorHex: "#FFAA00",
    onMarkTaken: {},
    onSkip: {}
  )
}

#Preview("Maintenance (tap)") {
  MarkTakenView(
    medicationName: "Vitamin D",
    detail: "2000 IU · 1 capsule",
    isHighRisk: false,
    colorHex: nil,
    onMarkTaken: {},
    onSkip: {}
  )
}
