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

  // MARK: - ComplianceCount real query

  @Test func emptyStoreReturnsZeros() throws {
    let context = try makeContext()
    let result = try ComplianceCount.compliance(for: .now, in: context)
    #expect(result == ComplianceCount.Result(taken: 0, scheduled: 0))
  }

  @Test func scheduledCountsOnlyMaintenanceSlotsApplyingToToday() throws {
    let context = try makeContext()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1 // Monday → ISO weekday 1
    let day = try #require(calendar.date(from: components))

    let daily = Medication(displayName: "Daily Med", unitForm: .tablet, kind: .maintenance)
    daily.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1, medication: daily),
      ScheduledDose(hour: 20, minute: 0, quantity: 1, medication: daily),
    ]
    let weekdayOnly = Medication(displayName: "Weekday Med", unitForm: .tablet, kind: .maintenance)
    weekdayOnly.schedule = [
      // Tuesday-only — should NOT count on a Monday.
      ScheduledDose(hour: 9, minute: 0, quantity: 1, daysOfWeek: [2], medication: weekdayOnly),
    ]
    let prn = Medication(displayName: "PRN", unitForm: .tablet, kind: .prn)
    prn.schedule = [ScheduledDose(hour: 12, minute: 0, quantity: 1, medication: prn)]
    let archived = Medication(displayName: "Archived", unitForm: .tablet, kind: .maintenance)
    archived.isArchived = true
    archived.schedule = [ScheduledDose(hour: 7, minute: 0, quantity: 1, medication: archived)]
    context.insert(daily)
    context.insert(weekdayOnly)
    context.insert(prn)
    context.insert(archived)
    try context.save()

    let result = try ComplianceCount.compliance(for: day, in: context, calendar: calendar)
    // Only the two daily slots count: PRN excluded (kind), archived excluded,
    // weekdayOnly excluded (Tuesday-only).
    #expect(result == ComplianceCount.Result(taken: 0, scheduled: 2))
  }

  @Test func takenMatchesScheduledWhenEverySlotHasATakenEventInsideTheDay() throws {
    let context = try makeContext()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    let day = try #require(calendar.date(from: components))
    let startOfDay = calendar.startOfDay(for: day)

    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1, medication: med),
      ScheduledDose(hour: 20, minute: 0, quantity: 1, medication: med),
    ]
    context.insert(med)
    let morning = try #require(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay))
    let evening = try #require(calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startOfDay))
    context.insert(DoseEvent(medication: med, scheduledFor: morning, takenAt: morning, quantity: 1, status: .taken, loggedOn: .watch))
    context.insert(DoseEvent(medication: med, scheduledFor: evening, takenAt: evening, quantity: 1, status: .taken, loggedOn: .watch))
    try context.save()

    let result = try ComplianceCount.compliance(for: day, in: context, calendar: calendar)
    #expect(result == ComplianceCount.Result(taken: 2, scheduled: 2))
  }

  @Test func takenExcludesPRNAnytimeLogsWithNilScheduledFor() throws {
    let context = try makeContext()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = 1
    let day = try #require(calendar.date(from: components))
    let startOfDay = calendar.startOfDay(for: day)

    let scheduledMed = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    scheduledMed.schedule = [ScheduledDose(hour: 9, minute: 0, quantity: 1, medication: scheduledMed)]
    let prn = Medication(displayName: "Aspirin", unitForm: .tablet, kind: .prn)
    context.insert(scheduledMed)
    context.insert(prn)
    // Anytime log (no scheduledFor) — must not contribute to `taken`.
    let anytime = try #require(calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay))
    context.insert(DoseEvent(medication: scheduledMed, scheduledFor: nil, takenAt: anytime, quantity: 1, status: .taken, loggedOn: .watch))
    // PRN log — also no scheduledFor.
    let prnTime = try #require(calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startOfDay))
    context.insert(DoseEvent(medication: prn, scheduledFor: nil, takenAt: prnTime, quantity: 1, status: .taken, loggedOn: .watch))
    try context.save()

    let result = try ComplianceCount.compliance(for: day, in: context, calendar: calendar)
    #expect(result == ComplianceCount.Result(taken: 0, scheduled: 1))
  }

  // MARK: - ComplianceFooter copy

  @Test func footerCopyShowsCountWhenSomeButNotAllAreTaken() {
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 2, scheduled: 5)) == "2 of 5 doses taken")
  }

  @Test func footerCopyShowsAllDosesTakenWhenCountsMatch() {
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 3, scheduled: 3)) == "All doses taken")
  }

  @Test func footerCopyShowsNoDosesScheduledForRestDay() {
    // `scheduled == 0` reads as a rest day or empty regimen — the previous
    // "0 of 0 doses taken" skeleton wording was technically true but
    // confused two distinct states.
    #expect(ComplianceFooter.copy(for: ComplianceCount.Result(taken: 0, scheduled: 0)) == "No doses scheduled")
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

  // MARK: - DayDrillDownView.headerCopy

  @Test func headerCopyFormatsMealNameAndFiredTime() {
    let meal = PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 30)
    let section = DayDrillDownSection(mealID: meal.id, events: [])
    let copy = DayDrillDownView.headerCopy(for: section, meals: [meal])
    #expect(copy.hasPrefix("Pill Breakfast · fired "))
    // Locale-independent digit pair check — short-style time on the default
    // US locale renders "9:30 AM", but the colon-plus-digits substring is
    // what matters for the test.
    #expect(copy.contains("9:30"))
  }

  @Test func headerCopyForUngroupedSectionIsAsNeeded() {
    let section = DayDrillDownSection(mealID: nil, events: [])
    #expect(DayDrillDownView.headerCopy(for: section, meals: []) == "As-needed")
  }

  @Test func headerCopyGracefullyFallsBackWhenMealMissingFromQuery() {
    // A meal id pointing at a meal that didn't make it into the @Query
    // (e.g. a freshly-deleted meal still referenced by today's events)
    // renders a bare "Meal" header rather than crashing or showing the UUID.
    let section = DayDrillDownSection(mealID: UUID(), events: [])
    #expect(DayDrillDownView.headerCopy(for: section, meals: []) == "Meal")
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
