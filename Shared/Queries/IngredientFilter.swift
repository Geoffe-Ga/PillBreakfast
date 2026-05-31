import Foundation

/// Case-insensitive substring search over an `Ingredient`'s name + aliases,
/// shared by `IngredientsListView` (#156) and the medication editor's
/// component picker (#157) so the two surfaces can't drift on filter rules.
///
/// In-memory filter — the library is bounded at ~120 seeds + user additions,
/// well within a single sorted pass per keystroke.
@MainActor
public enum IngredientFilter {
  /// Returns the subset of `ingredients` whose `name` or one of `aliases`
  /// contains `query` (case-insensitive). A blank / whitespace-only query
  /// returns the input unchanged.
  public static func filter(_ ingredients: [Ingredient], query: String) -> [Ingredient] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return ingredients }
    return ingredients.filter { matches($0, needle: needle) }
  }

  /// True if `ingredient`'s name or any alias contains the pre-lowercased
  /// `needle`. `needle` must be lowercased and trimmed by the caller — the
  /// hot loop in `filter(_:query:)` lowercases once, not per-row.
  private static func matches(_ ingredient: Ingredient, needle: String) -> Bool {
    if ingredient.name.lowercased().contains(needle) { return true }
    return ingredient.aliases.contains { $0.lowercased().contains(needle) }
  }
}
