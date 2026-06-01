import SwiftUI

/// Compliance line at the bottom of the day drill-down. "All doses taken" when
/// the counts match, otherwise "N of M doses taken" — never "missed" or "late".
/// Skeleton placeholder; #194 wires the real per-day count.
struct ComplianceFooter: View {
  let result: ComplianceCount.Result

  var body: some View {
    HStack {
      Spacer()
      LiquidGlassTheme.Typography.footnote(Self.copy(for: result))
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .monospacedDigit()
      Spacer()
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  /// SPEC §7.3 — count-match wording. Never "missed" or "late":
  /// - `scheduled == 0` → "No doses scheduled" (a rest day or empty regimen).
  /// - `taken == scheduled > 0` → "All doses taken".
  /// - Otherwise → "N of M doses taken".
  /// `static` so the wording is testable without a SwiftUI runtime.
  static func copy(for result: ComplianceCount.Result) -> String {
    if result.scheduled == 0 { return "No doses scheduled" }
    if result.taken == result.scheduled { return "All doses taken" }
    return "\(result.taken) of \(result.scheduled) doses taken"
  }
}
