import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct ComplianceCountTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  // MARK: - ComplianceCount stub

  @Test func skeletonStubReturnsZeros() throws {
    let context = try makeContext()
    let result = ComplianceCount.compliance(for: .now, in: context)
    #expect(result == ComplianceCount.Result(taken: 0, scheduled: 0))
  }

  // MARK: - ComplianceFooter copy

  @Test func footerCopyShowsCountWhenScheduledHasDoses() {
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 2, scheduled: 5)) == "2 of 5 doses taken")
  }

  @Test func footerCopyShowsAllDosesTakenWhenCountsMatch() {
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 3, scheduled: 3)) == "All doses taken")
  }

  @Test func footerCopyDoesNotShowAllDosesTakenWhenNothingIsScheduled() {
    // The skeleton's zero/zero stub must not render "All doses taken" — the
    // user would read that as "you logged everything", but with no schedule
    // there's nothing to confirm.
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 0, scheduled: 0)) == "0 of 0 doses taken")
  }

  // MARK: - DayDrillDownView.sections partition

  @Test func sectionsPartitionsByMealIDWithUngroupedFallback() throws {
    let context = try makeContext()
    let calendar = Calendar(identifier: .gregorian)
    let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))

    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let vitaminD = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    let lithium = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    let aspirin = Medication(displayName: "Aspirin", unitForm: .tablet, kind: .prn)

    vitaminD.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: vitaminD, pillMeal: meal)]
    lithium.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: lithium, pillMeal: meal)]
    context.insert(meal)
    context.insert(vitaminD)
    context.insert(lithium)
    context.insert(aspirin)

    let scheduled = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day) ?? day
    let prnTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) ?? day

    let vitaminDEvent = DoseEvent(medication: vitaminD, scheduledFor: scheduled, takenAt: scheduled, quantity: 1, status: .taken, loggedOn: .watch)
    let lithiumEvent = DoseEvent(medication: lithium, scheduledFor: scheduled, takenAt: scheduled, quantity: 1, status: .taken, loggedOn: .watch)
    let prnEvent = DoseEvent(medication: aspirin, scheduledFor: nil, takenAt: prnTime, quantity: 1, status: .taken, loggedOn: .watch)
    context.insert(vitaminDEvent)
    context.insert(lithiumEvent)
    context.insert(prnEvent)
    try context.save()

    let events = [vitaminDEvent, lithiumEvent, prnEvent]
    let sections = DayDrillDownView.sections(for: events, calendar: calendar)
    #expect(sections.count == 2)
    // First section is the meal (its events appeared first chronologically).
    #expect(sections[0].mealID == meal.id)
    #expect(sections[0].events.count == 2)
    // Last section is ungrouped.
    #expect(sections[1].mealID == nil)
    #expect(sections[1].events.count == 1)
    #expect(sections[1].events.first?.medication?.id == aspirin.id)
  }

  @Test func sectionsOnEmptyInputReturnsEmpty() {
    // Guard against a future regression where an empty-sections case
    // causes a `List` layout issue.
    #expect(DayDrillDownView.sections(for: []).isEmpty)
  }

  @Test func mealIDLookupReturnsMealIDWhenSlotCarriesMeal() throws {
    // Direct positive-path test (the `sectionsPartitionsByMealIDWithUngroupedFallback`
    // case exercises this indirectly). Guards against a regression where
    // `mealID` always returns nil and the drill-down silently shows only
    // an "As-needed" section.
    let context = try makeContext()
    let calendar = Calendar(identifier: .gregorian)
    let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))

    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    med.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1, medication: med, pillMeal: meal)]
    context.insert(meal)
    context.insert(med)
    let scheduled = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day) ?? day
    let event = DoseEvent(medication: med, scheduledFor: scheduled, takenAt: scheduled, quantity: 1, status: .taken, loggedOn: .watch)
    context.insert(event)
    try context.save()

    #expect(DayDrillDownView.mealID(for: event, calendar: calendar) == meal.id)
  }

  @Test func mealIDLookupReturnsNilForUnscheduledEvent() throws {
    let context = try makeContext()
    let med = Medication(displayName: "Aspirin", unitForm: .tablet, kind: .prn)
    context.insert(med)
    let event = DoseEvent(medication: med, scheduledFor: nil, takenAt: .now, quantity: 1, status: .taken, loggedOn: .watch)
    context.insert(event)
    try context.save()

    #expect(DayDrillDownView.mealID(for: event) == nil)
  }

  @Test func mealIDLookupReturnsNilWhenScheduledSlotDoesNotCarryAMeal() throws {
    let context = try makeContext()
    let calendar = Calendar(identifier: .gregorian)
    let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))

    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    med.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1, medication: med)]
    context.insert(med)
    let scheduled = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
    let event = DoseEvent(medication: med, scheduledFor: scheduled, takenAt: scheduled, quantity: 1, status: .taken, loggedOn: .watch)
    context.insert(event)
    try context.save()

    #expect(DayDrillDownView.mealID(for: event, calendar: calendar) == nil)
  }
}
