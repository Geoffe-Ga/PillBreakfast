import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PillMealSuggestionTests {
  private func meal(_ name: String, _ hour: Int, _ minute: Int) -> PillMeal {
    PillMeal(name: name, targetHour: hour, targetMinute: minute)
  }

  @Test func noMealsWhenNoneExist() {
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 0), in: [])
    #expect(suggestion == .noMeals)
  }

  @Test func singleWhenOneMealWithinWindow() {
    let breakfast = meal("Pill Breakfast", 9, 0)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 0), in: [breakfast])
    guard case let .single(matched) = suggestion else {
      Issue.record("expected .single, got \(suggestion)")
      return
    }
    #expect(matched === breakfast)
  }

  @Test func multipleWhenSeveralMealsWithinWindow() {
    let early = meal("Early", 8, 50)
    let late = meal("Late", 9, 10)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 0), in: [early, late])
    guard case let .multiple(matched) = suggestion else {
      Issue.record("expected .multiple, got \(suggestion)")
      return
    }
    #expect(matched.count == 2)
    #expect(Set(matched.map(\.id)) == Set([early.id, late.id]))
  }

  @Test func createNewWhenMealsExistButNoneClose() {
    let dinner = meal("Pill Dinner", 18, 0)
    let bedtime = meal("Bedtime", 21, 0)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 0), in: [dinner, bedtime])
    #expect(suggestion == .createNew(hour: 9, minute: 0))
  }

  @Test func exactlyThirtyMinutesAwayStillMatches() {
    // The window is inclusive at 30 minutes.
    let breakfast = meal("Pill Breakfast", 9, 0)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 30), in: [breakfast])
    guard case .single = suggestion else {
      Issue.record("expected .single at the 30-min boundary, got \(suggestion)")
      return
    }
  }

  @Test func thirtyOneMinutesAwayDoesNotMatch() {
    let breakfast = meal("Pill Breakfast", 9, 0)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (9, 31), in: [breakfast])
    #expect(suggestion == .createNew(hour: 9, minute: 31))
  }

  @Test func matchWrapsAroundMidnight() {
    // 23:50 meal and a 00:05 dose are 15 min apart across midnight, not 1425.
    let bedtime = meal("Bedtime", 23, 50)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (0, 5), in: [bedtime])
    guard case let .single(matched) = suggestion else {
      Issue.record("expected .single across midnight, got \(suggestion)")
      return
    }
    #expect(matched === bedtime)
  }

  @Test func twentyNineMinutesAcrossMidnightMatches() {
    // 23:31 meal, 00:00 dose → 29 min across the midnight wrap → match.
    let bedtime = meal("Bedtime", 23, 31)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (0, 0), in: [bedtime])
    guard case .single = suggestion else {
      Issue.record("expected .single (29 min across midnight), got \(suggestion)")
      return
    }
  }

  @Test func thirtyOneMinutesAcrossMidnightDoesNotMatch() {
    // 23:29 meal, 00:00 dose → 31 min across the midnight wrap → no match.
    let bedtime = meal("Bedtime", 23, 29)
    let suggestion = PillMealSuggestion.propose(forDoseAt: (0, 0), in: [bedtime])
    #expect(suggestion == .createNew(hour: 0, minute: 0))
  }

  // MARK: - HealthKit bundled assignment (§8.4)

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func assignImportedSynthesizesDosesOnlyForPickedRows() throws {
    let context = try makeContext()
    let breakfast = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 0)
    context.insert(breakfast)
    let vitaminD = Medication(displayName: "Vitamin D", unitForm: .tablet, kind: .maintenance)
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let b12 = Medication(displayName: "B12", unitForm: .tablet, kind: .maintenance)
    for med in [vitaminD, lithium, b12] {
      context.insert(med)
    }
    try context.save()

    // 3 imports, user picks breakfast for two and "None" for the third.
    let created = try PillMealAssignment.assignImported([
      (vitaminD, breakfast),
      (lithium, breakfast),
      (b12, nil),
    ], in: context)

    #expect(created == 2)
    // Picked rows gained a dose at the meal's time, bound to the meal.
    #expect(vitaminD.schedule.count == 1)
    #expect(vitaminD.schedule.first?.hour == 9)
    #expect(vitaminD.schedule.first?.minute == 0)
    #expect(vitaminD.schedule.first?.pillMeal?.id == breakfast.id)
    #expect(lithium.schedule.first?.pillMeal?.id == breakfast.id)
    // The "None" row stays scheduleless.
    #expect(b12.schedule.isEmpty)
    #expect(breakfast.scheduledDoses.count == 2)
  }

  @Test func assignImportedWithNoPicksCreatesNothing() throws {
    let context = try makeContext()
    let med = Medication(displayName: "Vitamin D", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    try context.save()

    let created = try PillMealAssignment.assignImported([(med, nil)], in: context)
    #expect(created == 0)
    #expect(med.schedule.isEmpty)
  }

  @Test func assignImportedPropagatesQuantity() throws {
    let context = try makeContext()
    let breakfast = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 0)
    context.insert(breakfast)
    let med = Medication(displayName: "Vitamin D", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    try context.save()

    try PillMealAssignment.assignImported([(med, breakfast)], quantity: 2, in: context)
    #expect(med.schedule.first?.quantity == 2)
  }

  // MARK: - Earliest unassigned dose

  @Test func earliestUnassignedDoseSkipsBoundDosesAndPicksEarliest() throws {
    let lunch = meal("Lunch", 12, 0)
    // The 8:00 dose is the earliest overall but already bound — it must be
    // skipped in favour of the earliest *unassigned* dose (9:00).
    let bound = ScheduledDose(hour: 8, minute: 0, quantity: 1, pillMeal: lunch)
    let unassignedEarly = ScheduledDose(hour: 9, minute: 0, quantity: 1)
    let unassignedLate = ScheduledDose(hour: 21, minute: 0, quantity: 1)
    let result = PillMealSuggestion.earliestUnassignedDose(in: [bound, unassignedLate, unassignedEarly])
    let dose = try #require(result)
    #expect(dose.hour == 9)
    #expect(dose.minute == 0)
  }

  @Test func earliestUnassignedDoseIsNilWhenAllBound() {
    let breakfast = meal("Breakfast", 9, 0)
    let bound = ScheduledDose(hour: 9, minute: 0, quantity: 1, pillMeal: breakfast)
    #expect(PillMealSuggestion.earliestUnassignedDose(in: [bound]) == nil)
  }

  // MARK: - Time label

  @Test func timeLabelIsNonEmptyAndVariesByInput() {
    // Locale-agnostic regression anchor: a real formatter yields non-empty,
    // distinct strings for distinct times (a broken/constant impl would not).
    let morning = PillMealSuggestion.timeLabel(hour: 9, minute: 0)
    let evening = PillMealSuggestion.timeLabel(hour: 21, minute: 30)
    #expect(!morning.isEmpty)
    #expect(!evening.isEmpty)
    #expect(morning != evening)
  }
}
