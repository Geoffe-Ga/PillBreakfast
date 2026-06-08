import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct LogMedicationListTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @discardableResult
  private func medication(_ name: String, archived: Bool = false, in context: ModelContext) -> Medication {
    let med = Medication(displayName: name, unitForm: .tablet, kind: .maintenance)
    med.isArchived = archived
    context.insert(med)
    return med
  }

  @Test func activeMedsComeBeforeArchivedAndAreAlphabetised() throws {
    let ctx = try makeContext()
    medication("Zinc", in: ctx)
    medication("Aspirin", in: ctx)
    medication("OldMed", archived: true, in: ctx)

    let all = try ctx.fetch(FetchDescriptor<Medication>())
    let sections = LogMedicationList.sections(from: all)

    #expect(sections.map(\.id) == ["active", "archived"])
    #expect(sections[0].medications.map(\.displayName) == ["Aspirin", "Zinc"])
    #expect(sections[1].medications.map(\.displayName) == ["OldMed"])
  }

  @Test func searchFiltersByNameCaseInsensitively() throws {
    let ctx = try makeContext()
    medication("Lithium", in: ctx)
    medication("Gabapentin", in: ctx)

    let all = try ctx.fetch(FetchDescriptor<Medication>())
    let sections = LogMedicationList.sections(from: all, query: "LITH")

    #expect(sections.count == 1)
    #expect(sections[0].medications.map(\.displayName) == ["Lithium"])
  }

  @Test func emptyQueryReturnsEverything() throws {
    let ctx = try makeContext()
    medication("Lithium", in: ctx)
    medication("OldMed", archived: true, in: ctx)

    let all = try ctx.fetch(FetchDescriptor<Medication>())
    let sections = LogMedicationList.sections(from: all, query: "   ")

    #expect(sections.flatMap(\.medications).count == 2)
  }

  @Test func emptyStoreYieldsNoSections() throws {
    let ctx = try makeContext()
    let all = try ctx.fetch(FetchDescriptor<Medication>())
    #expect(LogMedicationList.sections(from: all).isEmpty)
  }
}
