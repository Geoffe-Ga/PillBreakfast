import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct SmartStackPlanTests {
  private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
  }

  // 1970-01-01 is a Thursday; 1970-01-04 is a Sunday (ISO 7).
  private let thursday = Date(timeIntervalSince1970: 0)
  private let sunday = Date(timeIntervalSince1970: 3 * 24 * 3600)

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @discardableResult
  private func med(
    _ name: String,
    hour: Int,
    minute: Int,
    daysOfWeek: [Int] = [],
    meal: PillMeal? = nil,
    in context: ModelContext
  ) -> Medication {
    let med = Medication(displayName: name, unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    let dose = ScheduledDose(hour: hour, minute: minute, quantity: 1, daysOfWeek: daysOfWeek, medication: med, pillMeal: meal)
    context.insert(dose)
    med.schedule = [dose]
    return med
  }

  private func meds(in context: ModelContext) throws -> [Medication] {
    try context.fetch(FetchDescriptor<Medication>())
  }

  @Test func oneMaintenanceDoseFormsOneGroup() throws {
    let context = try makeContext()
    med("Lithium", hour: 8, minute: 0, in: context)
    let groups = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: thursday, calendar: utcCalendar)
    #expect(groups.count == 1)
    #expect(groups[0].doseCount == 1)
    #expect(groups[0].groupName == "Lithium")
  }

  @Test func pillMealWithTwoDosesIsOneGroupNamedForTheMeal() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Morning", targetHour: 8, targetMinute: 0)
    context.insert(meal)
    med("Lithium", hour: 8, minute: 0, meal: meal, in: context)
    med("Vitamin D", hour: 8, minute: 0, meal: meal, in: context)
    let groups = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: thursday, calendar: utcCalendar)
    #expect(groups.count == 1)
    #expect(groups[0].groupName == "Morning")
    #expect(groups[0].doseCount == 2)
  }

  @Test func twoMedsAtDifferentTimesAreTwoSortedGroups() throws {
    let context = try makeContext()
    med("Evening", hour: 20, minute: 0, in: context)
    med("Morning", hour: 8, minute: 0, in: context)
    let groups = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: thursday, calendar: utcCalendar)
    #expect(groups.count == 2)
    #expect(groups[0].scheduledAt < groups[1].scheduledAt)
    #expect(groups[0].groupName == "Morning")
  }

  @Test func daysOfWeekRestrictsToMatchingDay() throws {
    let context = try makeContext()
    med("MondayMed", hour: 8, minute: 0, daysOfWeek: [1], in: context) // ISO Monday
    let onSunday = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: sunday, calendar: utcCalendar)
    #expect(onSunday.isEmpty)
  }

  @Test func groupLabelFormats() {
    #expect(SmartStackPlan.groupLabel(["A"]) == "A")
    #expect(SmartStackPlan.groupLabel(["A", "B"]) == "A · B")
    #expect(SmartStackPlan.groupLabel(["A", "B", "C"]) == "A · B · +1 more")
  }

  @discardableResult
  private func highRiskMed(_ name: String, hour: Int, minute: Int = 0, meal: PillMeal? = nil, in context: ModelContext) -> Medication {
    let medication = med(name, hour: hour, minute: minute, meal: meal, in: context)
    let ingredient = Ingredient(name: "\(name)-ingredient", isHighRisk: true)
    context.insert(ingredient)
    let component = MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 100)
    context.insert(component)
    medication.components = [component]
    return medication
  }

  @Test func nextNonHighRiskDoseIsNilWhenEveryDoseIsHighRisk() throws {
    let context = try makeContext()
    highRiskMed("Lithium", hour: 8, in: context)
    let groups = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: thursday, calendar: utcCalendar)
    #expect(groups.count == 1)
    #expect(groups[0].containsHighRisk)
    #expect(groups[0].nextNonHighRiskDose == nil)
  }

  @Test func nextNonHighRiskDosePicksTheNonHighRiskMedInAMixedGroup() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Morning", targetHour: 8, targetMinute: 0)
    context.insert(meal)
    highRiskMed("Lithium", hour: 8, meal: meal, in: context)
    med("Vitamin D", hour: 8, minute: 0, meal: meal, in: context)
    let groups = try SmartStackPlan.doseGroups(maintenanceMeds: meds(in: context), on: thursday, calendar: utcCalendar)
    #expect(groups.count == 1)
    #expect(groups[0].containsHighRisk)
    #expect(groups[0].nextNonHighRiskDose?.medicationName == "Vitamin D")
  }
}
