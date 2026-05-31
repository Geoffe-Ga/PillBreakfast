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

  /// Tertiary labels — timestamp captions, secondary row text. One step
  /// below `caption`.
  static func footnote(_ text: String) -> Text {
    Text(text).font(footnoteFont)
  }
}
