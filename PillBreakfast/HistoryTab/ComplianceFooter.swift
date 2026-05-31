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

  /// "All doses taken" when count == scheduled; otherwise "N of M doses taken".
  /// `static` so the wording is testable without a SwiftUI runtime.
  static func copy(for result: ComplianceCount.Result) -> String {
    if result.scheduled > 0, result.taken == result.scheduled {
      return "All doses taken"
    }
    return "\(result.taken) of \(result.scheduled) doses taken"
  }
}
