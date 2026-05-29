import SwiftData

/// Whether an ingredient may be deleted from the library, and if not, why — so the
/// caller's error message stays co-located with the rule rather than re-deriving it.
enum IngredientDeletionCheck: Equatable {
  case allowed
  /// A seeded library entry; never deletable.
  case seeded
  /// A user-added ingredient still referenced by a `MedicationComponent`.
  case referenced
}

@MainActor
enum IngredientDeletion {
  static func check(_ ingredient: Ingredient, in context: ModelContext) throws -> IngredientDeletionCheck {
    if IngredientLibrarySeeder.seededIDs.contains(ingredient.id) { return .seeded }
    let ingredientID = ingredient.id
    // Full fetch + in-memory check: a #Predicate over the optional `ingredient`
    // relationship isn't cleanly expressible in Swift 6 SwiftData, and the
    // component table is tiny. Don't "optimize" to a predicate without confirming
    // the optional-relationship form actually compiles.
    let referenced = try context
      .fetch(FetchDescriptor<MedicationComponent>())
      .contains { $0.ingredient?.id == ingredientID }
    return referenced ? .referenced : .allowed
  }
}
