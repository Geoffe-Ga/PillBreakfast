import SwiftUI

/// Soft-warning interstitial shown before a PRN dose that would cross an
/// ingredient ceiling or minimum interval (SPEC §2.3, §7.3). It **names the
/// ingredient** (not just the product) and always offers an override — this is a
/// warning, not a lockout; the user is the authority. High-risk products require
/// the press-and-hold to override; others override with a single tap.
struct SafetyWarningView: View {
  let violations: [Violation]
  let isHighRisk: Bool
  let onOverride: () -> Void
  let onCancel: () -> Void

  /// Captured once when the warning appears so the "X ago" elapsed times stay put
  /// while the user reads, rather than drifting on every re-render.
  @State private var now = Date.now

  private var messages: [ViolationMessage] {
    violations.map { ViolationMessageBuilder.message(for: $0, at: now) }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.standard) {
        ForEach(messages) { message in
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
              Image(systemName: "exclamationmark.triangle.fill")
              LiquidGlassTheme.Typography.medicationName(message.title)
            }
            ForEach(message.detailLines, id: \.self) { line in
              LiquidGlassTheme.Typography.caption(line)
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
            }
          }
        }

        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)

        // Override: high-risk products still demand the hold; the rest single-tap.
        if isHighRisk {
          HighRiskConfirmButton(hint: "Hold to confirm anyway", onConfirmed: onOverride)
        } else {
          Button("Confirm anyway", action: onOverride)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding()
    }
    .navigationTitle("Check first")
    .glassBackground()
  }
}
