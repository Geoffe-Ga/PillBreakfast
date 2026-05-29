import Foundation

/// A safety problem a prospective dose would cause, aggregated **by ingredient**
/// (the whole point of the ingredient layer — SPEC §5.1), not by product.
///
/// Typed, not a `String` message: the associated values carry the ingredient and
/// the numbers, and the UI (the soft-warning interstitial, EPIC_05_ISSUE_05)
/// shapes the wording. An empty `[Violation]` means safe; a non-empty result
/// means show the warning, naming each ingredient.
public enum Violation: Sendable, Hashable, Identifiable {
  /// Taking the dose would push the ingredient's day total over its ceiling.
  case ceiling(ingredient: Ingredient, current: Double, proposed: Double, ceiling: Double)
  /// The ingredient was last taken more recently than its minimum interval allows.
  case tooSoon(ingredient: Ingredient, lastTakenAt: Date, minInterval: Int)

  public var id: String {
    switch self {
    case let .ceiling(ingredient, _, _, _): "ceiling:\(ingredient.id)"
    case let .tooSoon(ingredient, _, _): "tooSoon:\(ingredient.id)"
    }
  }
}
