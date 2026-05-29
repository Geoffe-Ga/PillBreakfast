import Foundation
import SwiftData
import UserNotifications

/// Reschedules a dose reminder to a user-chosen wall-clock time (SPEC §8.3).
///
/// Deterministic: the caller supplies `now` and the `Calendar`. The snooze is a
/// **one-shot** trigger under its own per-occurrence identifier. Re-snoozing the
/// same occurrence reuses that identifier, so `add` replaces it in place; the
/// daily repeating fire has a different identifier and is never touched.
@MainActor
public enum SnoozeRescheduler {
  static let snoozeIdentifierPrefix = "com.creekmasons.pillbreakfast.snooze."

  public enum SnoozeError: Error, Equatable {
    /// The calendar couldn't resolve the chosen wall-clock time (degenerate input,
    /// e.g. a broken timezone) — surfaced rather than silently firing at `now`.
    case unresolvableTime
  }

  /// - Parameter snoozeUntil: the target wall-clock time; only `hour`/`minute` are
  ///   read (a missing component is treated as 0, i.e. midnight).
  public static func snooze(
    scheduledDoseID: UUID,
    originalScheduledFor: Date,
    medicationName: String,
    snoozeUntil: DateComponents,
    now: Date,
    center: any NotificationScheduling,
    context: ModelContext,
    calendar: Calendar = .current
  ) async throws {
    let target = try resolveTarget(from: snoozeUntil, now: now, calendar: calendar)
    let id = identifier(scheduledDoseID: scheduledDoseID, originalScheduledFor: originalScheduledFor)

    let content = UNMutableNotificationContent()
    content.title = "Snoozed pill ready"
    content.body = medicationName // often the only line the user reads at a glance
    content.categoryIdentifier = NotificationCategory.maintenanceDose
    content.sound = .default

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target),
      repeats: false
    )
    // `add` replaces any pending request with the same identifier in place, so a
    // re-snooze atomically swaps the prior snooze — no separate cancel that could
    // leave the user with no reminder if `add` then failed.
    try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))

    // Count the snooze only after it's actually scheduled, so the fourth-snooze
    // warning reflects snoozes that really happened.
    try SnoozeRecordStore.increment(scheduledDoseID: scheduledDoseID, on: now, at: now, in: context, calendar: calendar)
  }

  static func identifier(scheduledDoseID: UUID, originalScheduledFor: Date) -> String {
    "\(snoozeIdentifierPrefix)\(scheduledDoseID.uuidString).\(isoFormatter.string(from: originalScheduledFor))"
  }

  /// The chosen wall-clock time today, or tomorrow if it's already passed. Throws
  /// rather than silently firing at `now`/in the past on a degenerate calendar.
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
