import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PillMealTests {
  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func pillMealRoundTripsThroughSwiftData() throws {
    let context = try makeInMemoryContext()

    let meal = PillMeal(
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0
    )
    context.insert(meal)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<PillMeal>())
    #expect(fetched.count == 1)
    let stored = try #require(fetched.first)
    #expect(stored.name == "Pill Breakfast")
    #expect(stored.targetHour == 9)
    #expect(stored.targetMinute == 30)
    #expect(stored.sortOrder == 0)

    context.delete(stored)
    try context.save()
    #expect(try context.fetch(FetchDescriptor<PillMeal>()).isEmpty)
  }

  @Test func scheduledDosePillMealRelationshipIsOptional() throws {
    let context = try makeInMemoryContext()

    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let dose = ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medication)
    medication.schedule = [dose]
    context.insert(medication)

    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    context.insert(meal)
    dose.pillMeal = meal
    try context.save()

    let stored = try #require(try context.fetch(FetchDescriptor<ScheduledDose>()).first)
    #expect(stored.pillMeal?.id == meal.id)

    stored.pillMeal = nil
    try context.save()
    let cleared = try #require(try context.fetch(FetchDescriptor<ScheduledDose>()).first)
    #expect(cleared.pillMeal == nil)
    // The meal itself survives — clearing the dose-side relationship
    // doesn't delete the meal (no cascade).
    #expect(try context.fetch(FetchDescriptor<PillMeal>()).count == 1)
  }

  @Test func existingScheduledDoseFetchesReturnNilPillMeal() throws {
    let context = try makeInMemoryContext()

    let medication = Medication(displayName: "Aspirin", unitForm: .tablet, kind: .maintenance)
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(medication)
    try context.save()

    let stored = try #require(try context.fetch(FetchDescriptor<ScheduledDose>()).first)
    #expect(stored.pillMeal == nil)
  }

  @Test func deletingPillMealLeavesAssignedScheduledDoseInPlace() throws {
    let context = try makeInMemoryContext()

    let meal = PillMeal(name: "Pill Dinner", targetHour: 21, targetMinute: 0)
    let medication = Medication(displayName: "Lamictal", unitForm: .tablet, kind: .maintenance)
    let dose = ScheduledDose(hour: 21, minute: 0, quantity: 1, medication: medication, pillMeal: meal)
    medication.schedule = [dose]
    context.insert(meal)
    context.insert(medication)
    try context.save()

    context.delete(meal)
    try context.save()

    #expect(try context.fetch(FetchDescriptor<PillMeal>()).isEmpty)
    // The dose survives the meal's deletion (no cascade from `PillMeal` to
    // `ScheduledDose`). The editor in the next issue is responsible for
    // blocking deletion while assignments exist or clearing them first;
    // the model layer's only contract here is "deleting a meal does not
    // delete the doses that pointed at it."
    let surviving = try context.fetch(FetchDescriptor<ScheduledDose>())
    #expect(surviving.count == 1)
  }
}
