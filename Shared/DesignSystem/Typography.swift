import SwiftUI

/// `Text`-builder helpers that bake in the typographic tokens, so call sites
/// write `LiquidGlassTheme.Typography.medicationName("Lithium")` instead of
/// repeating `.font(...)` everywhere. The `…Font` constants live on the
/// namespace itself; these wrap them (different names to avoid colliding with
/// the stored font properties).
public extension LiquidGlassTheme.Typography {
  /// Prominent status/headline text (not a medication name).
  static func title(_ text: String) -> Text {
    Text(text).font(titleFont)
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
}
