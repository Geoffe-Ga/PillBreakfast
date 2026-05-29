import SwiftData

/// Decides whether an ingredient may be deleted from the library. Seeded entries
/// are permanent; user-added ones can go only if no `MedicationComponent` still
/// references them (deleting a referenced ingredient would orphan a product's
/// safety math).
@MainActor
enum IngredientDeletion {
  static func isDeletable(_ ingredient: Ingredient, in context: ModelContext) throws -> Bool {
    guard !IngredientLibrarySeeder.seededIDs.contains(ingredient.id) else { return false }
    let ingredientID = ingredient.id
    // Full fetch + in-memory check: a #Predicate over the optional `ingredient`
    // relationship isn't cleanly expressible in Swift 6 SwiftData, and the
    // component table is tiny. Don't "optimize" to a predicate without confirming
    // the optional-relationship form actually compiles.
    let referenced = try context
      .fetch(FetchDescriptor<MedicationComponent>())
      .contains { $0.ingredient?.id == ingredientID }
    return !referenced
  }
}
