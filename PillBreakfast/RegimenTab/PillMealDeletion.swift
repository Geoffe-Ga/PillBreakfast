/// Whether a Pill Meal may be deleted (mirrors `IngredientDeletion` shape).
enum PillMealDeletionCheck: Equatable {
  case allowed
  /// At least one `ScheduledDose` still references the meal.
  case referenced(doseCount: Int)
}

@MainActor
enum PillMealDeletion {
  /// Uses the meal's `scheduledDoses` inverse relationship rather than a
  /// `ScheduledDose` table scan — the inverse is what the schema exists
  /// for and the count grows linearly with the regimen, not the store.
  static func check(_ meal: PillMeal) -> PillMealDeletionCheck {
    let count = meal.scheduledDoses.count
    return count == 0 ? .allowed : .referenced(doseCount: count)
  }
}
