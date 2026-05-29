import Foundation
@testable import PillBreakfast
import Testing
import UserNotifications

private struct AddFailure: Error {}

@MainActor
private final class FakeNotificationCenter: NotificationScheduling {
  private(set) var added: [UNNotificationRequest] = []
  var throwOnAdd = false

  func add(_ request: UNNotificationRequest) async throws {
    if throwOnAdd { throw AddFailure() }
    added.append(request)
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

  @Test func snoozeSchedulesOneShotRequestWithMedicationBody() async throws {
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
  }

  @Test func reSnoozeReusesTheSameIdentifierSoItReplacesInPlace() async throws {
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

    // Both adds reuse the same per-occurrence identifier, so the real center
    // replaces the prior snooze in place (idempotent reschedule).
    #expect(center.added.count == 2)
    #expect(Set(center.added.map(\.identifier)).count == 1)
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
    // Add-only ordering: a failed add leaves nothing scheduled (and never cancelled
    // a prior snooze), so the user's existing reminder survives.
    #expect(center.added.isEmpty)
  }

  @Test func resolveTargetRollsToTomorrowWhenTargetEqualsNow() throws {
    let cal = try calendar()
    let now = try date(2026, 5, 15, 9, 0, in: cal)
    // Exactly now → not strictly ahead → rolls to tomorrow (don't fire immediately).
    let target = try SnoozeRescheduler.resolveTarget(from: DateComponents(hour: 9, minute: 0), now: now, calendar: cal)
    #expect(try target == date(2026, 5, 16, 9, 0, in: cal))
  }
}
