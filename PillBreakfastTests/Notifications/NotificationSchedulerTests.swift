import Foundation
@testable import PillBreakfast
import Testing
import UserNotifications

@MainActor
struct NotificationSchedulerTests {
  private func medicationDTO(
    name: String,
    kind: MedicationKind = .maintenance,
    isArchived: Bool = false,
    schedule: [ScheduledDoseDTO]
  ) -> MedicationDTO {
    MedicationDTO(
      id: UUID(),
      displayName: name,
      fullName: nil,
      unitForm: .tablet,
      kind: kind,
      colorHex: nil,
      notes: nil,
      isArchived: isArchived,
      createdAt: .now,
      healthKitConceptID: nil,
      prnAvailableQuantities: [],
      components: [],
      schedule: schedule
    )
  }

  @Test func dailyDoseProducesOneNamespacedRequest() throws {
    let dose = ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [medicationDTO(name: "Vitamin D", schedule: [dose])]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.identifier == "com.creekmasons.pillbreakfast.dose.\(dose.id.uuidString)")
    #expect(request.content.title == "Pills · 1 to take")
    #expect(request.content.body == "Vitamin D")
    #expect(request.content.categoryIdentifier == NotificationCategory.maintenanceDose)

    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.dateComponents.hour == 8)
    #expect(trigger.dateComponents.minute == 0)
    #expect(trigger.dateComponents.weekday == nil)
    #expect(trigger.repeats)
  }

  @Test func multiDayDoseProducesOneRequestPerWeekday() {
    let dose = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [1, 3, 5])
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [medicationDTO(name: "Metformin", schedule: [dose])]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 3)
    #expect(requests.allSatisfy { $0.identifier.hasPrefix(NotificationScheduler.identifierPrefix) })
    // ISO Monday (1) maps to Calendar weekday 2.
    let weekdays = requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday }.sorted()
    #expect(weekdays == [2, 4, 6])
  }

  @Test func archivedAndPRNMedsAreSkipped() {
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Archived", isArchived: true, schedule: [ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])]),
        medicationDTO(name: "PRN", kind: .prn, schedule: [ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])]),
      ]
    )
    #expect(NotificationScheduler.makeRequests(from: snapshot).isEmpty)
  }

  @Test func bodyAggregatesNamesAtSameTimeWithOverflow() throws {
    let slot = (hour: 8, minute: 0)
    func dose() -> ScheduledDoseDTO {
      ScheduledDoseDTO(id: UUID(), hour: slot.hour, minute: slot.minute, quantity: 1, daysOfWeek: [])
    }
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Aspirin", schedule: [dose()]),
        medicationDTO(name: "Lithium", schedule: [dose()]),
        medicationDTO(name: "Vitamin D", schedule: [dose()]),
        medicationDTO(name: "Zinc", schedule: [dose()]),
      ]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 4)
    // Every notification at the 8:00 slot reports the full count and first two names.
    let titles = Set(requests.map(\.content.title))
    #expect(titles == ["Pills · 4 to take"])
    let body = try #require(requests.first?.content.body)
    #expect(body == "Aspirin · Lithium · +2 more") // names sorted, first two + overflow
  }

  @Test func medicationNameRoundTripsThroughUserInfo() throws {
    // The snooze action recovers the medication name from `userInfo`, not the
    // display body — so reformatting the body (e.g. "Time to take Vitamin D")
    // can't silently flow back into the rescheduled notification. Pin the
    // schedule-time write so a regression on `makeContent` trips the suite.
    let dose = ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [medicationDTO(name: "Vitamin D", schedule: [dose])]
    )

    let request = try #require(NotificationScheduler.makeRequests(from: snapshot).first)
    let stored = request.content.userInfo[NotificationScheduler.medicationNameUserInfoKey] as? String
    // Currently the user-info string is the same display body the user reads,
    // but the assertion is on the key being populated and matching the body —
    // future refactors that diverge them must update this expectation
    // intentionally.
    #expect(stored == request.content.body)
    #expect(stored == "Vitamin D")
    // And the resolver returns the same string for a freshly-scheduled request.
    #expect(NotificationScheduler.medicationName(from: request.content) == "Vitamin D")
  }

  @Test func medicationNameFallsBackToBodyWhenUserInfoMissing() {
    // Legacy / hand-scheduled requests without the userInfo key should keep
    // showing the body (which is the medication label) rather than the
    // aggregate "Pills · N to take" title.
    let content = UNMutableNotificationContent()
    content.title = "Pills · 1 to take"
    content.body = "Vitamin D"
    #expect(NotificationScheduler.medicationName(from: content) == "Vitamin D")
  }

  @Test func medicationNameFallsBackToTitleWhenBodyAndUserInfoMissing() {
    // Last-resort fallback: better to show the title than an empty string.
    let content = UNMutableNotificationContent()
    content.title = "Pills · 1 to take"
    #expect(NotificationScheduler.medicationName(from: content) == "Pills · 1 to take")
  }

  // MARK: - Meal-aware grouping (#191)

  @Test func mealAssignmentProducesOneRequestTitledWithMealName() throws {
    let mealID = UUID()
    let meal = PillMealDTO(
      id: mealID,
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0,
      createdAt: .now
    )
    let dose1 = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    let dose2 = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Vitamin D", schedule: [dose1]),
        medicationDTO(name: "Lithium", schedule: [dose2]),
      ],
      pillMeals: [meal]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.content.title == "Pill Breakfast")
    #expect(request.content.body == "Lithium · Vitamin D")
    #expect(request.content.categoryIdentifier == NotificationCategory.maintenanceDose)
    // Meal identifier carries the `meal.` infix and is not parseable as a single dose id.
    #expect(request.identifier.contains(".dose.meal.\(mealID.uuidString)"))
    #expect(NotificationScheduler.scheduledDoseID(fromIdentifier: request.identifier) == nil)
  }

  @Test func ungroupedDosesStillProduceTheExistingTimeSlotTitle() {
    // Regression pin: a snapshot with no meals at all behaves identically
    // to pre-#191 — one request per dose, "Pills · N to take" title.
    let dose1 = ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])
    let dose2 = ScheduledDoseDTO(id: UUID(), hour: 8, minute: 0, quantity: 1, daysOfWeek: [])
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Aspirin", schedule: [dose1]),
        medicationDTO(name: "Lithium", schedule: [dose2]),
      ],
      pillMeals: []
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 2)
    let titles = Set(requests.map(\.content.title))
    #expect(titles == ["Pills · 2 to take"])
    let bodies = Set(requests.map(\.content.body))
    #expect(bodies == ["Aspirin · Lithium"])
  }

  @Test func mixedRegimenProducesOneMealRequestPlusOneTimeSlotRequest() {
    let mealID = UUID()
    let meal = PillMealDTO(
      id: mealID,
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0,
      createdAt: .now
    )
    let mealDose = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    let ungroupedDose = ScheduledDoseDTO(id: UUID(), hour: 14, minute: 0, quantity: 1, daysOfWeek: [])
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Vitamin D", schedule: [mealDose]),
        medicationDTO(name: "Aspirin", schedule: [ungroupedDose]),
      ],
      pillMeals: [meal]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 2)
    let titles = Set(requests.map(\.content.title))
    #expect(titles == ["Pill Breakfast", "Pills · 1 to take"])
  }

  @Test func mealReferencedDoseFallsBackToUngroupedWhenMealMissing() {
    // A dose pointing at a meal that didn't make it into the snapshot
    // (e.g. concurrent edit, partial sync) still fires its existing
    // per-slot notification rather than vanishing.
    let dose = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: UUID())
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [medicationDTO(name: "Vitamin D", schedule: [dose])],
      pillMeals: []
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 1)
    #expect(requests.first?.content.title == "Pills · 1 to take")
    #expect(requests.first?.content.body == "Vitamin D")
  }

  @Test func sameMealDifferentSlotsProduceTwoRequests() {
    // Pin the `MealSlotKey` logic: a meal whose assigned doses fire at
    // different wall-clock times still produces a request per slot.
    let mealID = UUID()
    let meal = PillMealDTO(
      id: mealID,
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0,
      createdAt: .now
    )
    let morningDose = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    let afternoonDose = ScheduledDoseDTO(id: UUID(), hour: 14, minute: 0, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Vitamin D", schedule: [morningDose]),
        medicationDTO(name: "Aspirin", schedule: [afternoonDose]),
      ],
      pillMeals: [meal]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 2)
    // Both titled with the meal; bodies differ because the slot-keyed
    // grouping puts each med under its own slot.
    let titles = Set(requests.map(\.content.title))
    #expect(titles == ["Pill Breakfast"])
    let bodies = Set(requests.map(\.content.body))
    #expect(bodies == ["Vitamin D", "Aspirin"])
  }

  @Test func mealBodyAggregatesNamesAtSameSlotWithOverflow() throws {
    // Parallel to `bodyAggregatesNamesAtSameTimeWithOverflow` on the ungrouped
    // path — confirms `bodyText` is wired identically in `makeMealContent`.
    let mealID = UUID()
    let meal = PillMealDTO(
      id: mealID,
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0,
      createdAt: .now
    )
    func dose() -> ScheduledDoseDTO {
      ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [], pillMealID: mealID)
    }
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Aspirin", schedule: [dose()]),
        medicationDTO(name: "Lithium", schedule: [dose()]),
        medicationDTO(name: "Vitamin D", schedule: [dose()]),
        medicationDTO(name: "Zinc", schedule: [dose()]),
      ],
      pillMeals: [meal]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    #expect(requests.count == 1)
    let body = try #require(requests.first?.content.body)
    #expect(body == "Aspirin · Lithium · +2 more")
  }

  @Test func multiDayMealEmitsOneRequestPerWeekday() {
    let mealID = UUID()
    let meal = PillMealDTO(
      id: mealID,
      name: "Pill Breakfast",
      targetHour: 9,
      targetMinute: 30,
      sortOrder: 0,
      createdAt: .now
    )
    let dose1 = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [1, 3, 5], pillMealID: mealID)
    let dose2 = ScheduledDoseDTO(id: UUID(), hour: 9, minute: 30, quantity: 1, daysOfWeek: [1, 3, 5], pillMealID: mealID)
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [
        medicationDTO(name: "Vitamin D", schedule: [dose1]),
        medicationDTO(name: "Lithium", schedule: [dose2]),
      ],
      pillMeals: [meal]
    )

    let requests = NotificationScheduler.makeRequests(from: snapshot)
    // Two doses, three weekdays each, but consolidated under the meal:
    // one request per (meal, slot, weekday) — three total.
    #expect(requests.count == 3)
    let titles = Set(requests.map(\.content.title))
    #expect(titles == ["Pill Breakfast"])
  }
}
