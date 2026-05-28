import SwiftUI

/// Typed design tokens for PillBreakfast's Liquid Glass aesthetic (SPEC §9).
///
/// Centralizing colors, typography, spacing, and materials here keeps call sites
/// free of hard-coded values and enforces the project's color discipline *by
/// construction*: there is deliberately no general-purpose accent token, so a
/// screen cannot tint itself without reaching for the one high-risk color.
public enum LiquidGlassTheme {
  public enum Colors {
    /// Monochromatic baseline; tracks the system light/dark appearance.
    public static let primaryText: Color = .primary
    public static let secondaryText: Color = .secondary

    /// The **only** color in the design system. Reserved for high-risk meds —
    /// the warm amber of the press-and-hold confirmation (SPEC §9, CLAUDE.md).
    /// There is intentionally no `accentColor`; baseline UI stays glass + mono.
    public static let highRiskAccent = Color(red: 0.96, green: 0.66, blue: 0.27)
  }

  public enum Typography {
    /// SF Pro Rounded, title-shaped — medication names (SPEC §9).
    public static let medicationNameFont: Font = .system(.title, design: .rounded, weight: .semibold)
    /// SF Pro (Display at this size), title3-shaped, monospaced digits — dosage
    /// figures, so changing digits don't shift the layout.
    public static let dosageFont: Font = .system(.title3, design: .default, weight: .medium).monospacedDigit()
    /// SF Pro Rounded caption for supporting text.
    public static let captionFont: Font = .system(.caption, design: .rounded)
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
}
