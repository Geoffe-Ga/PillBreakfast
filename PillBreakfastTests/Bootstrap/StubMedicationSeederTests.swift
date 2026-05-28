import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct StubMedicationSeederTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func seedInsertsHighRiskStubWithComponentAndSchedule() throws {
    let context = try makeInMemoryContext()
    try StubMedicationSeeder.seedIfNeeded(context: context)

    let meds = try context.fetch(FetchDescriptor<Medication>())
    #expect(meds.count == 1)
    let stub = try #require(meds.first)
    #expect(stub.id == StubMedicationSeeder.stubMedicationID)
    #expect(stub.displayName == "Stub Lithium 300mg")
    #expect(stub.kind == .maintenance)
    #expect(stub.isHighRisk) // Lithium ingredient is high-risk

    #expect(stub.components.count == 1)
    #expect(stub.components.first?.dosagePerUnitMg == 300)
    #expect(stub.components.first?.ingredient?.id == StubMedicationSeeder.lithiumIngredientID)

    #expect(stub.schedule.count == 1)
    #expect(stub.schedule.first?.hour == 8)
    #expect(stub.schedule.first?.quantity == 1)
  }

  @Test func seedIsIdempotent() throws {
    let context = try makeInMemoryContext()
    try StubMedicationSeeder.seedIfNeeded(context: context)
    try StubMedicationSeeder.seedIfNeeded(context: context)

    #expect(try context.fetch(FetchDescriptor<Medication>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<MedicationComponent>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<ScheduledDose>()).count == 1)
  }

  @Test func seededStubSurvivesRegimenSnapshotRoundTrip() throws {
    let source = try makeInMemoryContext()
    try StubMedicationSeeder.seedIfNeeded(context: source)
    let snapshot = try RegimenSnapshot.from(context: source)

    let destination = try makeInMemoryContext()
    try snapshot.apply(to: destination)

    let meds = try destination.fetch(FetchDescriptor<Medication>())
    #expect(meds.first?.displayName == "Stub Lithium 300mg")
    #expect(meds.first?.components.first?.ingredient?.name == "Lithium Carbonate")
  }
}
