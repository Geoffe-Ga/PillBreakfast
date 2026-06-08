import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct LogNextDoseServiceTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  /// A maintenance med scheduled at `now`'s wall-clock time so the dose is
  /// pending at `now`. `highRisk` attaches a high-risk ingredient component.
  @discardableResult
  private func med(_ name: String, at now: Date, highRisk: Bool, in context: ModelContext) -> Medication {
    let medication = Medication(displayName: name, unitForm: .tablet, kind: .maintenance)
    context.insert(medication)
    let ingredient = Ingredient(name: "\(name)-ingredient", isHighRisk: highRisk)
    context.insert(ingredient)
    let component = MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 100)
    context.insert(component)
    medication.components = [component]
    let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
    let dose = ScheduledDose(hour: comps.hour ?? 8, minute: comps.minute ?? 0, quantity: 1, medication: medication)
    context.insert(dose)
    medication.schedule = [dose]
    return medication
  }

  private func spec(for medication: Medication, at now: Date) -> NextDoseSpec {
    NextDoseSpec(medicationID: medication.id, scheduledFor: now, quantity: 1, medicationName: medication.displayName)
  }

  private func doseEventCount(_ context: ModelContext) throws -> Int {
    try context.fetch(FetchDescriptor<DoseEvent>()).count
  }

  @Test func successLogsExactlyOneDoseEvent() throws {
    let context = try makeContext()
    let now = Date()
    let medication = med("Gabapentin", at: now, highRisk: false, in: context)
    let outcome = try LogNextDoseService.log(spec(for: medication, at: now), in: context, at: now)
    #expect(outcome == .logged)
    #expect(try doseEventCount(context) == 1)
  }

  @Test func highRiskRefusedAndWritesNothing() throws {
    let context = try makeContext()
    let now = Date()
    let medication = med("Lithium", at: now, highRisk: true, in: context)
    #expect(throws: LogIntentError.self) {
      try LogNextDoseService.log(spec(for: medication, at: now), in: context, at: now)
    }
    #expect(try doseEventCount(context) == 0)
  }

  @Test func archivedMedicationThrowsAndWritesNothing() throws {
    let context = try makeContext()
    let now = Date()
    let medication = med("Gabapentin", at: now, highRisk: false, in: context)
    medication.isArchived = true
    #expect(throws: LogIntentError.self) {
      try LogNextDoseService.log(spec(for: medication, at: now), in: context, at: now)
    }
    #expect(try doseEventCount(context) == 0)
  }

  @Test func unknownMedicationIDThrowsAndWritesNothing() throws {
    let context = try makeContext()
    let now = Date()
    let phantom = NextDoseSpec(medicationID: UUID(), scheduledFor: now, quantity: 1, medicationName: "Ghost")
    #expect(throws: LogIntentError.self) {
      try LogNextDoseService.log(phantom, in: context, at: now)
    }
    #expect(try doseEventCount(context) == 0)
  }

  @Test func alreadyLoggedIsNoOpOnSecondCall() throws {
    let context = try makeContext()
    let now = Date()
    let medication = med("Gabapentin", at: now, highRisk: false, in: context)
    let dose = spec(for: medication, at: now)
    #expect(try LogNextDoseService.log(dose, in: context, at: now) == .logged)
    #expect(try LogNextDoseService.log(dose, in: context, at: now) == .alreadyLogged)
    #expect(try doseEventCount(context) == 1)
  }
}
