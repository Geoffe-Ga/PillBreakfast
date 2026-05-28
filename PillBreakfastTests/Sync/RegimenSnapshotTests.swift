import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct RegimenSnapshotTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func fixture() -> RegimenSnapshot {
    let lithium = UUID()
    let lithobid = UUID()
    return RegimenSnapshot(
      ingredients: [
        IngredientDTO(
          id: lithium,
          name: "Lithium Carbonate",
          aliases: ["Lithobid"],
          isHighRisk: true,
          dailyCeilingMg: 1200,
          minIntervalMinutes: nil
        ),
      ],
      medications: [
        MedicationDTO(
          id: lithobid,
          displayName: "Lithobid",
          fullName: "Lithium Carbonate 300mg",
          unitForm: .tablet,
          kind: .maintenance,
          colorHex: "#FFAA00",
          notes: nil,
          isArchived: false,
          createdAt: Date(timeIntervalSince1970: 1_700_000_000),
          healthKitConceptID: nil,
          prnAvailableQuantities: [],
          components: [ComponentDTO(id: UUID(), ingredientID: lithium, dosagePerUnitMg: 300)],
          schedule: [ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])]
        ),
      ]
    )
  }

  @Test func snapshotCodableRoundTrip() throws {
    let snapshot = fixture()
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: data)
    #expect(decoded == snapshot)
    #expect(decoded.schemaVersion == RegimenSnapshot.currentSchemaVersion)
  }

  @Test func fromContextThenApplyReproducesTheStore() throws {
    let source = try makeInMemoryContext()
    let ingredient = Ingredient(name: "Lithium Carbonate", isHighRisk: true, dailyCeilingMg: 1200)
    let medication = Medication(displayName: "Lithobid", unitForm: .tablet, kind: .maintenance)
    medication.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 300)]
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    source.insert(medication)
    try source.save()

    let snapshot = try RegimenSnapshot.from(context: source)

    let destination = try makeInMemoryContext()
    try snapshot.apply(to: destination)

    let meds = try destination.fetch(FetchDescriptor<Medication>())
    #expect(meds.count == 1)
    let applied = try #require(meds.first)
    #expect(applied.displayName == "Lithobid")
    #expect(applied.components.count == 1)
    #expect(applied.components.first?.ingredient?.name == "Lithium Carbonate")
    #expect(applied.schedule.first?.hour == 8)
    #expect(try destination.fetch(FetchDescriptor<Ingredient>()).count == 1)
  }

  @Test func applyUpsertsNewMedAndArchivesMissingOne() throws {
    let source = try makeInMemoryContext()
    source.insert(Medication(displayName: "Lithobid", unitForm: .tablet, kind: .maintenance))
    try source.save()

    let destination = try makeInMemoryContext()
    let preexisting = Medication(displayName: "Old Lithium", unitForm: .tablet, kind: .maintenance)
    destination.insert(preexisting)
    try destination.save()

    let snapshot = try RegimenSnapshot.from(context: source)
    try snapshot.apply(to: destination)

    let meds = try destination.fetch(FetchDescriptor<Medication>())
    #expect(meds.contains { $0.displayName == "Lithobid" })
    let archived = try #require(meds.first { $0.id == preexisting.id })
    #expect(archived.isArchived)
  }

  @Test func reApplyingDoesNotDuplicateOrOrphanChildren() throws {
    let source = try makeInMemoryContext()
    let ingredient = Ingredient(name: "Acetaminophen")
    let medication = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    medication.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 500)]
    source.insert(medication)
    try source.save()
    let snapshot = try RegimenSnapshot.from(context: source)

    let destination = try makeInMemoryContext()
    try snapshot.apply(to: destination)
    try snapshot.apply(to: destination)

    #expect(try destination.fetch(FetchDescriptor<Medication>()).count == 1)
    #expect(try destination.fetch(FetchDescriptor<MedicationComponent>()).count == 1)
    #expect(try destination.fetch(FetchDescriptor<Ingredient>()).count == 1)
  }

  @Test func applyThrowsOnDanglingIngredientReference() throws {
    let orphanComponentID = UUID()
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        MedicationDTO(
          id: UUID(),
          displayName: "Mystery",
          fullName: nil,
          unitForm: .tablet,
          kind: .prn,
          colorHex: nil,
          notes: nil,
          isArchived: false,
          createdAt: .now,
          healthKitConceptID: nil,
          prnAvailableQuantities: [],
          components: [ComponentDTO(id: orphanComponentID, ingredientID: UUID(), dosagePerUnitMg: 1)],
          schedule: []
        ),
      ]
    )
    let context = try makeInMemoryContext()
    #expect(throws: SyncError.self) {
      try snapshot.apply(to: context)
    }
  }

  @Test func applyRejectsFutureSchemaVersion() throws {
    let snapshot = RegimenSnapshot(
      schemaVersion: RegimenSnapshot.currentSchemaVersion + 1,
      ingredients: [],
      medications: []
    )
    let context = try makeInMemoryContext()
    #expect(throws: SyncError.unsupportedSchemaVersion(RegimenSnapshot.currentSchemaVersion + 1)) {
      try snapshot.apply(to: context)
    }
  }

  @Test func fromContextSkipsArchivedMedications() throws {
    let context = try makeInMemoryContext()
    context.insert(Medication(displayName: "Active", unitForm: .tablet, kind: .maintenance))
    let archived = Medication(displayName: "Archived", unitForm: .tablet, kind: .maintenance)
    archived.isArchived = true
    context.insert(archived)
    try context.save()

    let snapshot = try RegimenSnapshot.from(context: context)
    #expect(snapshot.medications.count == 1)
    #expect(snapshot.medications.first?.displayName == "Active")
  }
}
