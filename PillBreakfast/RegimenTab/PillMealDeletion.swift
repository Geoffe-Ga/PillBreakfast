import SwiftData

/// Whether a Pill Meal may be deleted (mirrors `IngredientDeletion` shape).
enum PillMealDeletionCheck: Equatable {
  case allowed
  /// At least one `ScheduledDose` still references the meal.
  case referenced(doseCount: Int)
}

@MainActor
enum PillMealDeletion {
  static func check(_ meal: PillMeal, in context: ModelContext) throws -> PillMealDeletionCheck {
    let mealID = meal.id
    let referencingCount = try context
      .fetch(FetchDescriptor<ScheduledDose>())
      .count { $0.pillMeal?.id == mealID }
    return referencingCount == 0 ? .allowed : .referenced(doseCount: referencingCount)
  }
}
