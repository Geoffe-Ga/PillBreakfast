import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PillMealEditorTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  // MARK: - Deletion guard

  @Test func deletionAllowedWhenNoDosesReferenceTheMeal() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    context.insert(meal)
    try context.save()

    let refetched = try #require(try context.fetch(FetchDescriptor<PillMeal>()).first)
    #expect(PillMealDeletion.check(refetched) == .allowed)
  }

  @Test func deletionBlockedWhenAtLeastOneDoseReferencesTheMeal() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let dose = ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: med, pillMeal: meal)
    med.schedule = [dose]
    context.insert(meal)
    context.insert(med)
    try context.save()

    let refetched = try #require(try context.fetch(FetchDescriptor<PillMeal>()).first)
    #expect(PillMealDeletion.check(refetched) == .referenced(doseCount: 1))
  }

  @Test func deletionCountReflectsMultipleReferences() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let medA = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let medB = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    medA.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medA, pillMeal: meal)]
    medB.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medB, pillMeal: meal)]
    context.insert(meal)
    context.insert(medA)
    context.insert(medB)
    try context.save()

    let refetched = try #require(try context.fetch(FetchDescriptor<PillMeal>()).first)
    #expect(PillMealDeletion.check(refetched) == .referenced(doseCount: 2))
  }

  // MARK: - Time propagation

  @Test func changingMealTimePropagatesToEveryAssignedDose() throws {
    let context = try makeContext()
    let meal = PillMeal(name: "Pill Dinner", targetHour: 21, targetMinute: 0)
    let medA = Medication(displayName: "Lithium PM", unitForm: .tablet, kind: .maintenance)
    let medB = Medication(displayName: "Lamictal", unitForm: .tablet, kind: .maintenance)
    let doseA = ScheduledDose(hour: 21, minute: 0, quantity: 1, medication: medA, pillMeal: meal)
    let doseB = ScheduledDose(hour: 21, minute: 0, quantity: 1, medication: medB, pillMeal: meal)
    medA.schedule = [doseA]
    medB.schedule = [doseB]
    context.insert(meal)
    context.insert(medA)
    context.insert(medB)
    try context.save()

    meal.applyTime(targetHour: 22, targetMinute: 30)
    try context.save()

    let refetched = try #require(try context.fetch(FetchDescriptor<PillMeal>()).first)
    #expect(refetched.targetHour == 22)
    #expect(refetched.targetMinute == 30)
    for dose in refetched.scheduledDoses {
      #expect(dose.hour == 22)
      #expect(dose.minute == 30)
    }
  }

  @Test func unchangedMealTimeDoesNotTouchDoses() throws {
    // If a save doesn't change the time, doses aren't rewritten — keeps
    // SwiftData from generating spurious change records.
    let context = try makeContext()
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let dose = ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: med, pillMeal: meal)
    med.schedule = [dose]
    context.insert(meal)
    context.insert(med)
    try context.save()

    meal.applyTime(targetHour: 9, targetMinute: 30)

    #expect(dose.hour == 9)
    #expect(dose.minute == 30)
  }

  // MARK: - MedicationFormState round-trip with pillMealID

  @Test func medicationFormStateRoundTripsPillMealAssignment() throws {
    let context = try makeContext()
    let ingredient = Ingredient(name: "Cholecalciferol")
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    medication.schedule = [
      ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medication, pillMeal: meal),
    ]
    context.insert(ingredient)
    context.insert(meal)
    context.insert(medication)
    try context.save()

    let form = MedicationFormState(medication: medication)
    #expect(form.schedules.count == 1)
    #expect(form.schedules.first?.pillMealID == meal.id)

    // The draft re-applied with the same meal id rebuilds the relationship.
    form.componentDraft.ingredientID = ingredient.id
    form.componentDraft.dosagePerUnitMg = 50
    try form.apply(to: medication, in: context)
    try context.save()

    let stored = try #require(try context.fetch(FetchDescriptor<Medication>()).first)
    #expect(stored.schedule.first?.pillMeal?.id == meal.id)
  }

  // MARK: - PillMealsListSection subtitle

  @Test func subtitleFormatsTimeAndPluralizesDoseCount() {
    let zero = PillMeal(name: "Empty", targetHour: 9, targetMinute: 30)
    let one = PillMeal(name: "Single", targetHour: 9, targetMinute: 30)
    one.scheduledDoses = [ScheduledDose(hour: 9, minute: 30, quantity: 1)]
    let many = PillMeal(name: "Many", targetHour: 9, targetMinute: 30)
    many.scheduledDoses = [
      ScheduledDose(hour: 9, minute: 30, quantity: 1),
      ScheduledDose(hour: 9, minute: 30, quantity: 2),
    ]

    #expect(PillMealsListSection.subtitle(for: zero).contains("No doses"))
    #expect(PillMealsListSection.subtitle(for: one).contains("1 dose"))
    #expect(PillMealsListSection.subtitle(for: many).contains("2 doses"))
    // The time portion appears as a short-style 12-hour string on default
    // locales (e.g. "9:30 AM"); assert only on the digit pair so the test
    // is locale-independent.
    #expect(PillMealsListSection.subtitle(for: zero).contains("9:30"))
  }
}
