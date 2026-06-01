import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PillMealOnboardingServiceTests {
  // MARK: - Clustering

  @Test func twoDosesWithinFifteenMinutesClusterIntoOneSuggestion() {
    let doses = [
      ScheduledDose(hour: 9, minute: 30, quantity: 1),
      ScheduledDose(hour: 9, minute: 45, quantity: 1),
    ]
    let suggestions = PillMealOnboardingService.suggestions(from: doses)
    #expect(suggestions.count == 1)
    let suggestion = try? #require(suggestions.first)
    #expect(suggestion?.doseIDs.count == 2)
    #expect(suggestion?.hour == 9)
    #expect(suggestion?.minute == 30)
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
