import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct HealthMedicationMapperTests {
  private func healthDraft(
    _ name: String,
    conceptID: String = "concept-token",
    scheduled: Bool = false
  ) -> HealthMedicationDraft {
    HealthMedicationDraft(healthKitConceptID: conceptID, displayName: name, hasSchedule: scheduled)
  }

  // MARK: - toDraft

  @Test func toDraftPreservesNameAndConceptToken() {
    let source = healthDraft("Lithium", conceptID: "lithium-token")
    let result = HealthMedicationMapper.toDraft(source)
    #expect(result.displayName == "Lithium")
    #expect(result.healthKitConceptID == "lithium-token")
  }

  @Test func toDraftGivesANewPillBreakfastSideID() {
    // The Health-draft id is the import-sheet row identity; the MedicationDraft
    // id is the persistence-side identity. They are deliberately distinct so the
    // user can re-import without colliding.
    let source = healthDraft("Lithium")
    let result = HealthMedicationMapper.toDraft(source)
    #expect(result.id != source.id)
  }

  // MARK: - suggestedIngredient

  @Test func suggestedIngredientMatchesByCanonicalName() throws {
    let library = try seededLibrary()
    let draft = MedicationDraft(displayName: "Ibuprofen 200mg", healthKitConceptID: "x")
    let match = HealthMedicationMapper.suggestedIngredient(for: draft, in: library)
    #expect(match?.name == "Ibuprofen")
  }

  @Test func suggestedIngredientMatchesByAliasCaseInsensitively() throws {
    let library = try seededLibrary()
    let draft = MedicationDraft(displayName: "Paracetamol 500", healthKitConceptID: "x")
    let match = HealthMedicationMapper.suggestedIngredient(for: draft, in: library)
    #expect(match?.name == "Acetaminophen")
  }

  @Test func suggestedIngredientReturnsNilWhenNothingMatches() throws {
    let library = try seededLibrary()
    let draft = MedicationDraft(displayName: "Lithium Carbonate", healthKitConceptID: "x")
    // No seeded ingredient mentions Lithium; library covers OTC ingredients only.
    #expect(HealthMedicationMapper.suggestedIngredient(for: draft, in: library) == nil)
  }

  // MARK: - ConfirmComponentsView gating

  @Test func canImportRequiresAtLeastOneIngredientPerDraft() {
    let a = MedicationDraft(displayName: "A", healthKitConceptID: "a")
    let b = MedicationDraft(displayName: "B", healthKitConceptID: "b")
    let ing1 = UUID()
    let ing2 = UUID()
    // Both drafts have a selection → enabled.
    #expect(ConfirmComponentsView.canImport(
      drafts: [a, b],
      selections: [a.id: [ing1], b.id: [ing2]]
    ))
    // Only one of the two has a selection → disabled.
    #expect(!ConfirmComponentsView.canImport(
      drafts: [a, b],
      selections: [a.id: [ing1]]
    ))
    // Selection set exists but is empty → disabled.
    #expect(!ConfirmComponentsView.canImport(
      drafts: [a],
      selections: [a.id: []]
    ))
    // No drafts at all → disabled (no-op import would otherwise be allowed).
    #expect(!ConfirmComponentsView.canImport(drafts: [], selections: [:]))
  }

  // MARK: - Fixtures

  /// Builds an in-memory seeded library so the suggestion logic runs against the
  /// same ingredient set the app ships with.
  private func seededLibrary() throws -> [Ingredient] {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: Ingredient.self, Medication.self, MedicationComponent.self,
      ScheduledDose.self, DoseEvent.self,
      configurations: configuration
    )
    let context = ModelContext(container)
    try IngredientLibrarySeeder.seedIfNeeded(context: context)
    return try context
      .fetch(FetchDescriptor<Ingredient>())
      .sorted { $0.name < $1.name }
  }
}
