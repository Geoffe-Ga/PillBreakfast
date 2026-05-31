import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct IngredientFilterTests {
  /// Three-ingredient fixture covering: a name with no aliases, a name with
  /// one alias, and a name with multiple aliases. Pinned values stay simple
  /// so the assertions are about filter behaviour, not data fidelity.
  private func fixture() -> [Ingredient] {
    [
      Ingredient(name: "Acetaminophen", aliases: ["Paracetamol", "APAP"]),
      Ingredient(name: "Ibuprofen", aliases: []),
      Ingredient(name: "Lithium carbonate", aliases: ["Lithium"]),
    ]
  }

  @Test func emptyQueryReturnsAllIngredients() {
    let result = IngredientFilter.filter(fixture(), query: "")
    #expect(result.count == 3)
  }

  @Test func whitespaceOnlyQueryReturnsAllIngredients() {
    // A user mid-search whose typed query is just whitespace shouldn't see
    // an empty list — the no-op filter is the natural interpretation.
    let result = IngredientFilter.filter(fixture(), query: "   ")
    #expect(result.count == 3)
  }

  @Test func filterMatchesNameSubstringCaseInsensitively() {
    #expect(IngredientFilter.filter(fixture(), query: "ace").map(\.name) == ["Acetaminophen"])
    #expect(IngredientFilter.filter(fixture(), query: "ACE").map(\.name) == ["Acetaminophen"])
    #expect(IngredientFilter.filter(fixture(), query: "lith").map(\.name) == ["Lithium carbonate"])
  }

  @Test func filterMatchesAliasSubstringCaseInsensitively() {
    // "APAP" alias on Acetaminophen; case-insensitive substring on the alias.
    #expect(IngredientFilter.filter(fixture(), query: "apap").map(\.name) == ["Acetaminophen"])
    // "Paracetamol" alias — partial substring still matches.
    #expect(IngredientFilter.filter(fixture(), query: "PARAC").map(\.name) == ["Acetaminophen"])
  }

  @Test func nonMatchingQueryReturnsEmpty() {
    let result = IngredientFilter.filter(fixture(), query: "zzzzqqqq")
    #expect(result.isEmpty)
  }

  @Test func querySurroundedByWhitespaceIsTrimmedBeforeMatching() {
    // The list's `.searchable` binding can hand us a query with leading or
    // trailing whitespace (auto-correct, voice input); the filter trims so a
    // user typing " ibu " still finds Ibuprofen.
    let result = IngredientFilter.filter(fixture(), query: "  ibu  ")
    #expect(result.map(\.name) == ["Ibuprofen"])
  }

  @Test func multipleMatchesAreReturnedInInputOrder() {
    // Filter is order-preserving — the @Query already sorts by name in the
    // production call site, and search results should respect that order.
    let extra = [
      Ingredient(name: "Acetaminophen", aliases: ["APAP"]),
      Ingredient(name: "Acetylcysteine", aliases: []),
    ]
    let result = IngredientFilter.filter(extra, query: "acet")
    #expect(result.map(\.name) == ["Acetaminophen", "Acetylcysteine"])
  }
}
