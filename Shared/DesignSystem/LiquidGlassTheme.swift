import SwiftUI

/// Typed design tokens for PillBreakfast's Liquid Glass aesthetic (SPEC §9).
///
/// Centralizing colors, typography, spacing, materials, elevation, corner
/// radius, and motion here keeps call sites free of hard-coded values and
/// enforces the project's color discipline *by construction*: there is
/// deliberately no general-purpose accent token, so a screen cannot tint
/// itself without reaching for the one high-risk color.
public enum LiquidGlassTheme {
  public enum Colors {
    /// Monochromatic baseline; tracks the system light/dark appearance.
    public static let primaryText: Color = .primary
    public static let secondaryText: Color = .secondary

    /// The **only** color in the design system. Reserved for high-risk meds —
    /// the warm amber of the press-and-hold confirmation (SPEC §9, CLAUDE.md).
    /// There is intentionally no `accentColor`; baseline UI stays glass + mono.
    /// Fixed sRGB (not an adaptive/asset color) — the high-risk cue must be the
    /// same amber on every device and in both light and dark.
    public static let highRiskAccent = Color(red: 0.96, green: 0.66, blue: 0.27)
  }

  public enum Typography {
    /// SF Pro Rounded, large-title, bold — hero copy. The right-now dose
    /// card and the success state's "All caught up". Distinct from
    /// `titleFont` (title3) so a hero state can't be styled with the same
    /// weight as a section headline.
    public static let displayFont: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    /// SF Pro Rounded, title3, semibold — prominent status/headline text
    /// that isn't a medication name (e.g. "All caught up"). Distinct role
    /// from `medicationNameFont` so status copy doesn't borrow med-name
    /// semantics.
    public static let titleFont: Font = .system(.title3, design: .rounded, weight: .semibold)
    /// SF Pro Rounded, headline, semibold — iPhone section headers / row
    /// primary text. One step below `titleFont` for in-list emphasis.
    public static let headlineFont: Font = .system(.headline, design: .rounded, weight: .semibold)
    /// SF Pro Rounded, title — medication names (SPEC §9).
    public static let medicationNameFont: Font = .system(.title, design: .rounded, weight: .semibold)
    /// SF Pro (Display at this size), title3, monospaced digits — dosage
    /// figures, so changing digits don't shift the layout.
    public static let dosageFont: Font = .system(.title3, design: .default, weight: .medium).monospacedDigit()
    /// SF Pro Rounded caption (12 pt default) for the smallest supporting
    /// text — chip labels, dense list metadata.
    public static let captionFont: Font = .system(.caption, design: .rounded)
    /// SF Pro Rounded footnote (13 pt default) for legible secondary copy —
    /// row subtitles, ingredient summaries, "last logged" timestamps.
    /// Note: Apple's `.footnote` is one step *larger* than `.caption`, so
    /// this lands between caption and headline on the type scale despite
    /// the colloquial sense of "footnote".
    public static let footnoteFont: Font = .system(.footnote, design: .rounded)
  }

  /// Negative space is part of the design (SPEC §9) — explicit, named spacing
  /// rather than scattered magic numbers.
  public enum Spacing {
    public static let compact: CGFloat = 8
    public static let standard: CGFloat = 16
    public static let generous: CGFloat = 24
  }

  public enum Materials {
    /// Translucent surface for cards/rows layered over the glass background.
    public static let surface: Material = .ultraThin
  }

  /// Depth tokens for layered surfaces. Three levels: `flat` for inline
  /// content, `raised` for cards atop glass, `floating` for sheets and
  /// modal presentations. Values are deliberately conservative — Liquid
  /// Glass already implies depth through refraction; the shadow exists
  /// to disambiguate stacking, not to dominate.
  public struct Elevation: Sendable, Hashable {
    /// Shadow blur radius in points.
    public let radius: CGFloat
    /// Vertical shadow offset in points. Positive values push the shadow
    /// down (consistent with light from above).
    public let yOffset: CGFloat
    /// Black-channel opacity for the shadow. Stays under 0.15 so the
    /// shadow doesn't fight the glass material's own refraction.
    public let opacity: Double

    public static let flat = Elevation(radius: 0, yOffset: 0, opacity: 0)
    public static let raised = Elevation(radius: 6, yOffset: 2, opacity: 0.08)
    public static let floating = Elevation(radius: 16, yOffset: 6, opacity: 0.12)
  }

  /// Discrete corner radii. Picked from the same scale so concentric
  /// shapes nest cleanly (a `card` containing a `standard` button
  /// containing a `tight` chip preserves visual rhythm).
  public enum CornerRadius {
    /// Small chips, inline badges, single-letter indicators.
    public static let tight: CGFloat = 6
    /// Buttons, rows, single-line controls.
    public static let standard: CGFloat = 12
    /// Hero cards, sheets, presentation containers.
    public static let card: CGFloat = 20
  }

  /// Named animation presets. Three speeds tied to the polish surfaces:
  /// `snappy` for taps and confirmations (decisive feedback), `gentle`
  /// for screen-to-screen transitions (calm), `dramatic` for celebration
  /// states (success reveals). Surfaces compose these rather than
  /// inventing their own springs so motion stays coherent across the app.
  public enum Motion {
    /// Quick, lightly bouncy — button presses, dose advances.
    public static let snappy: Animation = .snappy(duration: 0.25, extraBounce: 0.1)
    /// Calm, no bounce — push/pop/sheet presentation transitions.
    public static let gentle: Animation = .smooth(duration: 0.35)
    /// Reach for this only on success/celebration reveals — "All caught
    /// up", first-time-setup completion.
    public static let dramatic: Animation = .bouncy(duration: 0.5, extraBounce: 0.2)
  }
}

public extension View {
  /// Applies the named elevation as a shadow. `.flat` produces no shadow
  /// (the modifier is a no-op for layouts that share a parent default).
  func elevation(_ elevation: LiquidGlassTheme.Elevation) -> some View {
    shadow(
      color: .black.opacity(elevation.opacity),
      radius: elevation.radius,
      x: 0,
      y: elevation.yOffset
    )
  }
}
