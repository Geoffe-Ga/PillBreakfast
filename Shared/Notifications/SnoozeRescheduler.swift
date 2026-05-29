import Foundation
import UserNotifications

/// Reschedules a dose reminder to a user-chosen wall-clock time (SPEC §8.3).
///
/// Deterministic: the caller supplies `now` and the `Calendar`. The snooze is a
/// **one-shot** trigger under its own namespaced identifier, so re-snoozing
/// cancels only the prior snooze for this occurrence — never the daily repeating
/// fire, which keeps firing on subsequent days untouched.
@MainActor
public enum SnoozeRescheduler {
  static let snoozeIdentifierPrefix = "com.creekmasons.pillbreakfast.snooze."

  enum SnoozeError: Error, Equatable {
    /// The calendar couldn't resolve the chosen wall-clock time (degenerate input,
    /// e.g. a broken timezone) — surfaced rather than silently firing at `now`.
    case unresolvableTime
  }

  public static func snooze(
    scheduledDoseID: UUID,
    originalScheduledFor: Date,
    medicationName: String,
    snoozeUntil: DateComponents,
    now: Date,
    center: any NotificationScheduling,
    calendar: Calendar = .current
  ) async throws {
    let target = try resolveTarget(from: snoozeUntil, now: now, calendar: calendar)
    let id = identifier(scheduledDoseID: scheduledDoseID, originalScheduledFor: originalScheduledFor)

    // Cancel only this occurrence's prior snooze (idempotent re-snooze). The daily
    // recurring request has a different identifier and is left alone.
    center.removePendingNotificationRequests(withIdentifiers: [id])

    let content = UNMutableNotificationContent()
    content.title = "Snoozed pill ready"
    content.body = medicationName // often the only line the user reads at a glance
    content.categoryIdentifier = NotificationCategory.maintenanceDose
    content.sound = .default

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target),
      repeats: false
    )
    try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
  }

  /// Namespaced per scheduled occurrence so a reschedule replaces the right snooze.
  static func identifier(scheduledDoseID: UUID, originalScheduledFor: Date) -> String {
    "\(snoozeIdentifierPrefix)\(scheduledDoseID.uuidString).\(isoFormatter.string(from: originalScheduledFor))"
  }

  /// The chosen wall-clock time today, or tomorrow if that time has already passed
  /// (post-midnight rollover — SPEC §8.3 line 372). Throws rather than silently
  /// falling back to `now`/`today`, which would fire immediately or in the past.
  static func resolveTarget(from components: DateComponents, now: Date, calendar: Calendar) throws -> Date {
    guard let today = calendar.date(
      bySettingHour: components.hour ?? 0,
      minute: components.minute ?? 0,
      second: 0,
      of: now
    ) else {
      throw SnoozeError.unresolvableTime
    }
    if today > now { return today }
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
      throw SnoozeError.unresolvableTime
    }
    return tomorrow
  }

  /// UTC ISO-8601 so the identifier is stable regardless of the device timezone.
  private static let isoFormatter = ISO8601DateFormatter()
}
