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

  @Test func pillMealInverseReflectsAssignedScheduledDoses() throws {
    let context = try makeInMemoryContext()

    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let dose1 = ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medication, pillMeal: meal)
    let dose2 = ScheduledDose(hour: 9, minute: 30, quantity: 2, medication: medication, pillMeal: meal)
    medication.schedule = [dose1, dose2]
    context.insert(meal)
    context.insert(medication)
    try context.save()

    // Refetch from the store rather than reading the inserted instance —
    // SwiftData populates the inverse during fetch, not at the time the
    // dose-side reference is assigned.
    let storedMeal = try #require(try context.fetch(FetchDescriptor<PillMeal>()).first)
    #expect(storedMeal.scheduledDoses.count == 2)
    let storedIDs = Set(storedMeal.scheduledDoses.map(\.id))
    #expect(storedIDs == Set([dose1.id, dose2.id]))
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
    // `ScheduledDose`) AND its back-pointer is cleared — that's the
    // `.nullify` contract on `PillMeal.scheduledDoses`. The editor in the
    // next issue is responsible for blocking deletion while assignments
    // exist; the model layer's contract here is: deleting a meal leaves
    // its doses in place with their `pillMeal` reference nilled.
    let surviving = try context.fetch(FetchDescriptor<ScheduledDose>())
    #expect(surviving.count == 1)
    #expect(surviving.first?.pillMeal == nil)
  }

  // MARK: - Bounds enforcement (#199)

  @Test func clampedTimePinsOutOfRangeToNearestBound() {
    #expect(PillMeal.clampedTime(hour: 25, minute: 70).hour == 23)
    #expect(PillMeal.clampedTime(hour: 25, minute: 70).minute == 59)
    #expect(PillMeal.clampedTime(hour: -1, minute: -5).hour == 0)
    #expect(PillMeal.clampedTime(hour: -1, minute: -5).minute == 0)
  }

  @Test func clampedTimeLeavesInRangeValuesUnchanged() {
    let time = PillMeal.clampedTime(hour: 9, minute: 30)
    #expect(time.hour == 9)
    #expect(time.minute == 30)
    // Boundary values are valid and must not move.
    let low = PillMeal.clampedTime(hour: 0, minute: 0)
    #expect(low.hour == 0 && low.minute == 0)
    let high = PillMeal.clampedTime(hour: 23, minute: 59)
    #expect(high.hour == 23 && high.minute == 59)
  }

  @Test func initClampsOutOfRangeTime() {
    let meal = PillMeal(name: "Bad", targetHour: 99, targetMinute: -10)
    #expect(meal.targetHour == 23)
    #expect(meal.targetMinute == 0)
  }

  @Test func applyTimeClampsAndPropagatesClampedValueToDoses() throws {
    let context = try makeInMemoryContext()
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let medication = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let dose = ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: medication, pillMeal: meal)
    medication.schedule = [dose]
    context.insert(meal)
    context.insert(medication)
    try context.save()

    // Reads `dose` in-memory without a refetch (unlike the inverse-relationship
    // tests above): `pillMeal: meal` is wired at `ScheduledDose` init, so
    // `applyTime` mutates these same instances directly — no fetch needed.
    // Out-of-range update must be clamped on the meal AND on the propagated dose.
    meal.applyTime(targetHour: 30, targetMinute: 75)
    #expect(meal.targetHour == 23)
    #expect(meal.targetMinute == 59)
    #expect(dose.hour == 23)
    #expect(dose.minute == 59)
  }

  @Test func applyTimeDoesNotPropagateWhenClampedValueMatchesCurrent() throws {
    let context = try makeInMemoryContext()
    let meal = PillMeal(name: "Night", targetHour: 23, targetMinute: 59)
    let medication = Medication(displayName: "Melatonin", unitForm: .tablet, kind: .maintenance)
    let dose = ScheduledDose(hour: 23, minute: 59, quantity: 1, medication: medication, pillMeal: meal)
    medication.schedule = [dose]
    context.insert(meal)
    context.insert(medication)
    try context.save()

    // Sentinel: detect any unwanted propagation.
    dose.hour = 8
    dose.minute = 0

    // (30, 75) clamps to (23, 59), which equals the meal's current time, so the
    // `changed` guard (which compares the *clamped* value) is false and doses
    // must not move. Locks in the non-obvious no-op produced by clamping.
    meal.applyTime(targetHour: 30, targetMinute: 75)
    #expect(dose.hour == 8)
    #expect(dose.minute == 0)
  }

  // MARK: - sortOrder tail-append (#203)

  @Test func nextSortOrderIsZeroWhenNoMeals() throws {
    let context = try makeInMemoryContext()
    #expect(try PillMeal.nextSortOrder(in: context) == 0)
  }

  @Test func nextSortOrderIsOnePastTheMaxNotTheCount() throws {
    let context = try makeInMemoryContext()
    // Reorder-created gaps: three meals but the max sortOrder (5) exceeds count−1.
    // `count` (3) would collide with the meal at 5; max+1 (6) tail-appends.
    for order in [0, 5, 2] {
      context.insert(PillMeal(name: "M\(order)", targetHour: 9, targetMinute: 0, sortOrder: order))
    }
    try context.save()
    #expect(try PillMeal.nextSortOrder(in: context) == 6)
  }

  @Test func newMealLandsAtTailOfSortOrderThenCreatedAtOrder() throws {
    let context = try makeInMemoryContext()
    let first = PillMeal(name: "Breakfast", targetHour: 8, targetMinute: 0, sortOrder: try PillMeal.nextSortOrder(in: context))
    context.insert(first)
    try context.save()
    let second = PillMeal(name: "Dinner", targetHour: 20, targetMinute: 0, sortOrder: try PillMeal.nextSortOrder(in: context))
    context.insert(second)
    try context.save()

    // The Regimen @Query sorts by sortOrder then createdAt — assert the new meal
    // appends to the end rather than jumping to the front.
    #expect(first.sortOrder == 0)
    #expect(second.sortOrder == 1)
    let ordered = try context.fetch(
      FetchDescriptor<PillMeal>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
    )
    #expect(ordered.map(\.name) == ["Breakfast", "Dinner"])
  }
}
