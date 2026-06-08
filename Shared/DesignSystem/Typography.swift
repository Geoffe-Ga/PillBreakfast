import SwiftUI

/// `Text`-builder helpers that bake in the typographic tokens, so call sites
/// write `LiquidGlassTheme.Typography.medicationName("Lithium")` instead of
/// repeating `.font(...)` everywhere. The `…Font` constants live on the
/// namespace itself; these wrap them (different names to avoid colliding with
/// the stored font properties).
public extension LiquidGlassTheme.Typography {
  /// Hero copy — right-now dose card, "All caught up" success state.
  static func display(_ text: String) -> Text {
    Text(text).font(displayFont)
  }

  /// Prominent status/headline text (not a medication name).
  static func title(_ text: String) -> Text {
    Text(text).font(titleFont)
  }

  /// iPhone section headers / row primary text — one step below `title`.
  static func headline(_ text: String) -> Text {
    Text(text).font(headlineFont)
  }

  /// A medication name styled per SPEC §9 (SF Pro Rounded).
  static func medicationName(_ text: String) -> Text {
    Text(text).font(medicationNameFont)
  }

  /// A dosage figure styled per SPEC §9 (monospaced digits, SF Pro Display).
  static func dosage(_ text: String) -> Text {
    Text(text).font(dosageFont)
  }

  /// Supporting caption text. Font-only, like the other builders — callers set
  /// foreground style explicitly so these stay pure typography (a builder that
  /// also baked in a color would silently override a caller's own style).
  static func caption(_ text: String) -> Text {
    Text(text).font(captionFont)
  }

  /// Legible secondary copy — row subtitles, "last logged" timestamps,
  /// ingredient summaries. Sits between caption and headline on the type
  /// scale (Apple's `.footnote` is 13 pt vs `.caption`'s 12 pt).
  static func footnote(_ text: String) -> Text {
    Text(text).font(footnoteFont)
  }

  /// Validation-error text on forms. Minimum `.footnote` (13 pt default) so the
  /// user-must-act prompt stays legible at default and smaller Dynamic Type
  /// settings — never dropped to `caption`. Color is set by the call site
  /// (`.red` for validation, never `highRiskAccent`). See issue #103.
  static func errorText(_ text: String) -> Text {
    Text(text).font(footnoteFont)
  }
}
