import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PillMealOnboardingServiceTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  // MARK: - Clustering

  @Test func twoDosesWithinFifteenMinutesClusterIntoOneSuggestion() throws {
    let doses = [
      ScheduledDose(hour: 9, minute: 30, quantity: 1),
      ScheduledDose(hour: 9, minute: 45, quantity: 1),
    ]
    let suggestions = PillMealOnboardingService.suggestions(from: doses)
    #expect(suggestions.count == 1)
    let suggestion = try #require(suggestions.first)
    #expect(suggestion.doseIDs.count == 2)
    #expect(suggestion.hour == 9)
    #expect(suggestion.minute == 30)
  }

  @Test func twoDosesThirtyFiveMinutesApartDoNotCluster() {
    let doses = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1),
      ScheduledDose(hour: 8, minute: 35, quantity: 1),
    ]
    // Two doses, each alone in its cluster — neither meets the minimum size.
    let suggestions = PillMealOnboardingService.suggestions(from: doses)
    #expect(suggestions.isEmpty)
  }

  @Test func singletonClusterIsFiltered() {
    let doses = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    let suggestions = PillMealOnboardingService.suggestions(from: doses)
    #expect(suggestions.isEmpty)
  }

  @Test func multipleClustersRoundTripWithIndependentDoseIDs() throws {
    let breakfast1 = ScheduledDose(hour: 9, minute: 30, quantity: 1)
    let breakfast2 = ScheduledDose(hour: 9, minute: 45, quantity: 1)
    let dinner1 = ScheduledDose(hour: 21, minute: 0, quantity: 1)
    let dinner2 = ScheduledDose(hour: 21, minute: 10, quantity: 1)
    let suggestions = PillMealOnboardingService.suggestions(from: [breakfast1, breakfast2, dinner1, dinner2])
    #expect(suggestions.count == 2)
    let bs = try #require(suggestions.first { $0.hour == 9 })
    let ds = try #require(suggestions.first { $0.hour == 21 })
    #expect(Set(bs.doseIDs) == Set([breakfast1.id, breakfast2.id]))
    #expect(Set(ds.doseIDs) == Set([dinner1.id, dinner2.id]))
  }

  @Test func clusteringIsInsertionOrderIndependent() {
    let dinner = ScheduledDose(hour: 21, minute: 0, quantity: 1)
    let breakfast1 = ScheduledDose(hour: 9, minute: 30, quantity: 1)
    let breakfast2 = ScheduledDose(hour: 9, minute: 45, quantity: 1)
    let dinner2 = ScheduledDose(hour: 21, minute: 15, quantity: 1)
    let suggestions = PillMealOnboardingService.suggestions(from: [dinner, breakfast1, breakfast2, dinner2])
    #expect(suggestions.count == 2)
    #expect(suggestions[0].hour == 9) // Earliest cluster first.
    #expect(suggestions[1].hour == 21)
  }

  // MARK: - Suggested name heuristic

  @Test func suggestedNameMapsByHourBuckets() {
    #expect(PillMealOnboardingService.suggestedName(forHour: 9, minute: 30) == "Pill Breakfast")
    #expect(PillMealOnboardingService.suggestedName(forHour: 12, minute: 30) == "Pill Lunch")
    #expect(PillMealOnboardingService.suggestedName(forHour: 19, minute: 0) == "Pill Dinner")
    #expect(PillMealOnboardingService.suggestedName(forHour: 2, minute: 0) == "Pill Meal at 2:00")
    #expect(PillMealOnboardingService.suggestedName(forHour: 23, minute: 5) == "Pill Meal at 23:05")
  }

  // MARK: - UserPreferences flag

  @Test func pillMealsOnboardedDefaultsFalseAndRoundTrips() throws {
    let prefs = UserPreferences()
    #expect(prefs.pillMealsOnboarded == false)

    var mutated = prefs
    mutated.pillMealsOnboarded = true
    #expect(mutated.pillMealsOnboarded == true)

    let encoded = try JSONEncoder().encode(mutated)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: encoded)
    #expect(decoded.pillMealsOnboarded == true)
  }

  // MARK: - Medication name enrichment

  @Test func medicationNamesAreDedupedInEncounterOrder() throws {
    let vitaminD = Medication(displayName: "Vitamin D", unitForm: .tablet, kind: .maintenance)
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let doses = [
      ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: vitaminD),
      ScheduledDose(hour: 9, minute: 35, quantity: 1, medication: lithium),
      // Second Vitamin D dose in the same cluster must not duplicate the name.
      ScheduledDose(hour: 9, minute: 40, quantity: 1, medication: vitaminD),
    ]
    let suggestions = PillMealOnboardingService.suggestions(from: doses)
    let suggestion = try #require(suggestions.first)
    #expect(suggestion.medicationNames == ["Vitamin D", "Lithium"])
  }

  // MARK: - Persistence

  @Test func savingSuggestionCreatesPillMealWithTimeAndAssignedDoses() throws {
    let context = try makeContext()
    let d1 = ScheduledDose(hour: 9, minute: 30, quantity: 1)
    let d2 = ScheduledDose(hour: 9, minute: 45, quantity: 1)
    context.insert(d1)
    context.insert(d2)
    try context.save()

    let suggestion = SuggestedMeal(
      suggestedName: "Morning Pills",
      hour: 9,
      minute: 30,
      doseIDs: [d1.id, d2.id]
    )
    let meal = try PillMealOnboardingService.persist(suggestion, in: context)

    #expect(meal.name == "Morning Pills")
    #expect(meal.targetHour == 9)
    #expect(meal.targetMinute == 30)
    #expect(Set(meal.scheduledDoses.map(\.id)) == Set([d1.id, d2.id]))
    #expect(d1.pillMeal?.id == meal.id)
    #expect(d2.pillMeal?.id == meal.id)

    let storedMeals = try context.fetch(FetchDescriptor<PillMeal>())
    #expect(storedMeals.count == 1)
  }

  @Test func persistWithBlankNameThrows() throws {
    let context = try makeContext()
    let dose = ScheduledDose(hour: 9, minute: 30, quantity: 1)
    context.insert(dose)
    try context.save()

    let blank = SuggestedMeal(
      suggestedName: "   ",
      hour: 9,
      minute: 30,
      doseIDs: [dose.id]
    )
    #expect(throws: PillMealOnboardingError.blankName) {
      try PillMealOnboardingService.persist(blank, in: context)
    }
    // Nothing persisted on the blank-name path.
    #expect(try context.fetch(FetchDescriptor<PillMeal>()).isEmpty)
    #expect(dose.pillMeal == nil)
  }

  @Test func skippingOneClusterLeavesItsDosesUnassigned() throws {
    let context = try makeContext()
    let b1 = ScheduledDose(hour: 9, minute: 30, quantity: 1)
    let b2 = ScheduledDose(hour: 9, minute: 45, quantity: 1)
    let dnr1 = ScheduledDose(hour: 21, minute: 0, quantity: 1)
    let dnr2 = ScheduledDose(hour: 21, minute: 10, quantity: 1)
    for dose in [b1, b2, dnr1, dnr2] {
      context.insert(dose)
    }
    try context.save()

    // Save only breakfast; skip dinner (never call persist for it).
    let breakfast = SuggestedMeal(suggestedName: "Breakfast", hour: 9, minute: 30, doseIDs: [b1.id, b2.id])
    try PillMealOnboardingService.persist(breakfast, in: context)

    #expect(try context.fetch(FetchDescriptor<PillMeal>()).count == 1)
    #expect(b1.pillMeal != nil)
    #expect(dnr1.pillMeal == nil)
    #expect(dnr2.pillMeal == nil)
  }

  @Test func persistAppendsSortOrderAfterExistingMeals() throws {
    let context = try makeContext()
    context.insert(PillMeal(name: "Existing", targetHour: 8, targetMinute: 0, sortOrder: 5))
    let dose = ScheduledDose(hour: 12, minute: 0, quantity: 1)
    let dose2 = ScheduledDose(hour: 12, minute: 10, quantity: 1)
    context.insert(dose)
    context.insert(dose2)
    try context.save()

    let suggestion = SuggestedMeal(suggestedName: "Lunch", hour: 12, minute: 0, doseIDs: [dose.id, dose2.id])
    let meal = try PillMealOnboardingService.persist(suggestion, in: context)
    #expect(meal.sortOrder == 6)
  }

  @Test func legacyPreferencesDecodeWithoutPillMealsOnboardedKey() throws {
    // A v3 RegimenSnapshot payload (no `pillMealsOnboarded` key) must decode
    // by defaulting the flag to `false` so the upgrade path shows the sheet.
    let legacyJSON = """
    {
      "highRiskHoldDurationSeconds": 0.5,
      "defaultSnoozeOffsetMinutes": 30
    }
    """
    let data = try #require(legacyJSON.data(using: .utf8))
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
    #expect(decoded.pillMealsOnboarded == false)
  }
}
