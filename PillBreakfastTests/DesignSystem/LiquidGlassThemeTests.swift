import Foundation
@testable import PillBreakfast
import SwiftUI
import Testing

@MainActor
struct LiquidGlassThemeTests {
  @Test func spacingTokensMatchSpec() {
    #expect(LiquidGlassTheme.Spacing.compact == 8)
    #expect(LiquidGlassTheme.Spacing.standard == 16)
    #expect(LiquidGlassTheme.Spacing.generous == 24)
  }

  @Test func highRiskAccentIsWarmAmber() {
    // The single sanctioned color in the system — pin its value so a refactor
    // can't silently shift the high-risk cue.
    let resolved = LiquidGlassTheme.Colors.highRiskAccent.resolve(in: EnvironmentValues())
    #expect(abs(resolved.red - 0.96) < 0.02)
    #expect(abs(resolved.green - 0.66) < 0.02)
    #expect(abs(resolved.blue - 0.27) < 0.02)
  }

  @Test func medicationNameBuilderAppliesRoundedFont() {
    // Pass through a variable so both sides use verbatim Text storage (a string
    // literal would resolve to localized storage and never compare equal).
    let name = "Lithium"
    #expect(
      LiquidGlassTheme.Typography.medicationName(name)
        == Text(name).font(LiquidGlassTheme.Typography.medicationNameFont)
    )
  }

  @Test func dosageBuilderAppliesMonospacedFont() {
    let figure = "300 mg"
    #expect(
      LiquidGlassTheme.Typography.dosage(figure)
        == Text(figure).font(LiquidGlassTheme.Typography.dosageFont)
    )
  }
}
