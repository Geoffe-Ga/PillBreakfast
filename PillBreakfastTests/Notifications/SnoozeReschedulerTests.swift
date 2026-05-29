import Foundation
@testable import PillBreakfast
import Testing
import UserNotifications

private struct AddFailure: Error {}

@MainActor
private final class FakeNotificationCenter: NotificationScheduling {
  private(set) var added: [UNNotificationRequest] = []
  private(set) var removedIdentifiers: [String] = []
  var throwOnAdd = false

  func add(_ request: UNNotificationRequest) async throws {
    if throwOnAdd { throw AddFailure() }
    added.append(request)
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removedIdentifiers.append(contentsOf: identifiers)
  }
}

@MainActor
struct SnoozeReschedulerTests {
  private func calendar() throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    return calendar
  }

  private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, in calendar: Calendar) throws -> Date {
    var components = DateComponents()
    components.year = y; components.month = mo; components.day = d; components.hour = h; components.minute = mi
    return try #require(calendar.date(from: components))
  }

  // MARK: - resolveTarget

  @Test func resolveTargetSameDayWhenTimeIsStillAhead() throws {
    let cal = try calendar()
    let now = try date(2026, 5, 15, 10, 0, in: cal)
    let target = try SnoozeRescheduler.resolveTarget(from: DateComponents(hour: 14, minute: 30), now: now, calendar: cal)
    #expect(try target == date(2026, 5, 15, 14, 30, in: cal))
  }

  @Test func resolveTargetRollsToTomorrowPastMidnight() throws {
    let cal = try calendar()
    let now = try date(2026, 5, 15, 23, 50, in: cal)
    // 06:30 already passed today → schedule for tomorrow.
    let target = try SnoozeRescheduler.resolveTarget(from: DateComponents(hour: 6, minute: 30), now: now, calendar: cal)
    #expect(try target == date(2026, 5, 16, 6, 30, in: cal))
  }

  // MARK: - snooze

  @Test func snoozeSchedulesOneShotRequestAndCancelsOnlyItsOwnID() async throws {
    let cal = try calendar()
    let center = FakeNotificationCenter()
    let doseID = UUID()
    let original = try date(2026, 5, 15, 8, 0, in: cal)

    try await SnoozeRescheduler.snooze(
      scheduledDoseID: doseID,
      originalScheduledFor: original,
      medicationName: "Vitamin D",
      snoozeUntil: DateComponents(hour: 14, minute: 30),
      now: date(2026, 5, 15, 10, 0, in: cal),
      center: center,
      calendar: cal
    )

    let request = try #require(center.added.first)
    #expect(center.added.count == 1)
    #expect(request.identifier.hasPrefix(SnoozeRescheduler.snoozeIdentifierPrefix))
    #expect(request.content.body == "Vitamin D")
    #expect(request.content.categoryIdentifier == NotificationCategory.maintenanceDose)

    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == false) // one-shot, never repeating

    // Cancelled only its own namespaced id — never the daily recurring fire.
    #expect(center.removedIdentifiers == [request.identifier])
    #expect(center.removedIdentifiers.allSatisfy { $0.hasPrefix(SnoozeRescheduler.snoozeIdentifierPrefix) })
  }

  @Test func reSnoozeReusesIDAndCancelsThePrevious() async throws {
    let cal = try calendar()
    let center = FakeNotificationCenter()
    let doseID = UUID()
    let original = try date(2026, 5, 15, 8, 0, in: cal)

    func snooze(hour: Int, minute: Int) async throws {
      try await SnoozeRescheduler.snooze(
        scheduledDoseID: doseID,
        originalScheduledFor: original,
        medicationName: "Vitamin D",
        snoozeUntil: DateComponents(hour: hour, minute: minute),
        now: date(2026, 5, 15, 10, 0, in: cal),
        center: center,
        calendar: cal
      )
    }
    try await snooze(hour: 14, minute: 30)
    try await snooze(hour: 16, minute: 0) // re-snooze to a new time

    // Same identifier both times (keyed on dose + original occurrence)...
    #expect(Set(center.added.map(\.identifier)).count == 1)
    // ...and each call cancelled the prior snooze for that id.
    let id = try #require(center.added.first).identifier
    #expect(center.removedIdentifiers.count(where: { $0 == id }) == 2)
  }

  @Test func snoozeRethrowsWhenCenterAddFails() async throws {
    let cal = try calendar()
    let center = FakeNotificationCenter()
    center.throwOnAdd = true
    let now = try date(2026, 5, 15, 10, 0, in: cal)

    await #expect(throws: AddFailure.self) {
      try await SnoozeRescheduler.snooze(
        scheduledDoseID: UUID(),
        originalScheduledFor: now,
        medicationName: "Vitamin D",
        snoozeUntil: DateComponents(hour: 14, minute: 30),
        now: now,
        center: center,
        calendar: cal
      )
    }
  }
}
