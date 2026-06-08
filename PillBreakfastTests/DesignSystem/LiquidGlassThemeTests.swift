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

  @Test func titleBuilderAppliesTitleFont() {
    let text = "All caught up"
    #expect(
      LiquidGlassTheme.Typography.title(text)
        == Text(text).font(LiquidGlassTheme.Typography.titleFont)
    )
  }

  @Test func shimmerExtensionAppliesModifier() {
    // Compile-presence + correct-modifier guard for the public shimmer() API
    // (the animation itself is visual and covered by snapshot tests later).
    #expect(Text("done").shimmer() is ModifiedContent<Text, ShimmerModifier>)
  }

  @Test func captionBuilderIsFontOnly() {
    // Caption applies only the font (no embedded foreground style), matching the
    // other builders.
    let text = "PRN"
    #expect(
      LiquidGlassTheme.Typography.caption(text)
        == Text(text).font(LiquidGlassTheme.Typography.captionFont)
    )
  }

  // MARK: - Extended typography, elevation, corner radius, motion

  @Test func displayBuilderAppliesDisplayFont() {
    let text = "All caught up"
    #expect(
      LiquidGlassTheme.Typography.display(text)
        == Text(text).font(LiquidGlassTheme.Typography.displayFont)
    )
  }

  @Test func headlineBuilderAppliesHeadlineFont() {
    let text = "Medications"
    #expect(
      LiquidGlassTheme.Typography.headline(text)
        == Text(text).font(LiquidGlassTheme.Typography.headlineFont)
    )
  }

  @Test func footnoteBuilderAppliesFootnoteFont() {
    let text = "Last logged 8:00 AM"
    #expect(
      LiquidGlassTheme.Typography.footnote(text)
        == Text(text).font(LiquidGlassTheme.Typography.footnoteFont)
    )
  }

  @Test func errorTextBuilderAppliesFootnoteFont() {
    // Pin the legible floor: validation errors must not drop below `.footnote`.
    let text = "Name required."
    #expect(
      LiquidGlassTheme.Typography.errorText(text)
        == Text(text).font(LiquidGlassTheme.Typography.footnoteFont)
    )
  }

  @Test func elevationFlatHasNoShadow() {
    let flat = LiquidGlassTheme.Elevation.flat
    #expect(flat.radius == 0)
    #expect(flat.yOffset == 0)
    #expect(flat.opacity == 0)
  }

  @Test func elevationRaisedMatchesCardShadowSpec() {
    let raised = LiquidGlassTheme.Elevation.raised
    #expect(raised.radius == 6)
    #expect(raised.yOffset == 2)
    #expect(raised.opacity == 0.08)
  }

  @Test func elevationFloatingMatchesSheetShadowSpec() {
    let floating = LiquidGlassTheme.Elevation.floating
    #expect(floating.radius == 16)
    #expect(floating.yOffset == 6)
    #expect(floating.opacity == 0.12)
  }

  @Test func elevationOpacityStaysUnderFightingTheGlassMaterial() {
    // Shadows above ~0.15 fight Liquid Glass's own refraction — pin the
    // implicit ceiling so a "make it pop" PR doesn't quietly drift the
    // tokens upward.
    let opacities = [
      LiquidGlassTheme.Elevation.flat.opacity,
      LiquidGlassTheme.Elevation.raised.opacity,
      LiquidGlassTheme.Elevation.floating.opacity,
    ]
    for opacity in opacities {
      #expect(opacity <= 0.15)
    }
  }

  @Test func cornerRadiusPinsExpectedValues() {
    #expect(LiquidGlassTheme.CornerRadius.tight == 6)
    #expect(LiquidGlassTheme.CornerRadius.standard == 12)
    #expect(LiquidGlassTheme.CornerRadius.card == 20)
  }

  @Test func cornerRadiiAreStrictlyIncreasing() {
    // Nested concentric shapes read cleanly when the radii increase along
    // the nesting depth (tight chip inside standard button inside card).
    // Pin the order so a swap doesn't silently produce visual chaos.
    #expect(LiquidGlassTheme.CornerRadius.tight < LiquidGlassTheme.CornerRadius.standard)
    #expect(LiquidGlassTheme.CornerRadius.standard < LiquidGlassTheme.CornerRadius.card)
  }

  @Test func motionTokensAreDistinct() {
    // SwiftUI's `Animation` doesn't expose its parameters for direct
    // inspection — assert each named token has a distinct string
    // representation so a copy-paste regression that points two tokens
    // at the same spring is caught.
    let snappy = String(describing: LiquidGlassTheme.Motion.snappy)
    let gentle = String(describing: LiquidGlassTheme.Motion.gentle)
    let dramatic = String(describing: LiquidGlassTheme.Motion.dramatic)
    #expect(snappy != gentle)
    #expect(gentle != dramatic)
    #expect(snappy != dramatic)
  }
}
