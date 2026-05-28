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
}
