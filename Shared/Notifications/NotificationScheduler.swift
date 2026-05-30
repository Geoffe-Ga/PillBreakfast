import Foundation
import os
import UserNotifications

/// Builds and schedules the watch's dose reminders. The whole pending set is
/// rebuilt from scratch on every regimen change (full rebuild, not a diff) per
/// CLAUDE.md — simpler and immune to stale `UNCalendarNotificationTrigger`s.
public enum NotificationScheduler {
  /// Namespace for our requests so a rebuild never cancels unrelated notifications.
  public static let identifierPrefix = "com.creekmasons.pillbreakfast.dose."

  /// watchOS silently caps pending notifications per app; past this the system
  /// drops the extras. We warn rather than fail; smarter prioritization is #93.
  static let systemPendingLimit = 64

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Notifications")

  /// Pure: turns a snapshot into the request set, with no side effects, so it's
  /// unit-testable without a notification environment. One request per scheduled
  /// dose (per weekday when `daysOfWeek` is non-empty; daily when empty).
  public static func makeRequests(from snapshot: RegimenSnapshot) -> [UNNotificationRequest] {
    let maintenance = snapshot.medications.filter { !$0.isArchived && $0.kind == .maintenance }

    // How many maintenance doses fire at a given wall-clock minute — drives the
    // "N to take" count and the name list in the body.
    let dosesAtTime: [TimeSlot: [String]] = Dictionary(grouping: maintenance.flatMap { med in
      med.schedule.map { (TimeSlot(hour: $0.hour, minute: $0.minute), med.displayName) }
    }, by: { $0.0 }).mapValues { $0.map(\.1).sorted() }

    var requests: [UNNotificationRequest] = []
    for medication in maintenance {
      for dose in medication.schedule {
        let slot = TimeSlot(hour: dose.hour, minute: dose.minute)
        let content = makeContent(namesAtSlot: dosesAtTime[slot] ?? [medication.displayName])
        for trigger in makeTriggers(for: dose) {
          requests.append(
            UNNotificationRequest(
              identifier: identifier(for: dose, weekday: trigger.weekday),
              content: content,
              trigger: trigger.trigger
            )
          )
        }
      }
    }
    return requests
  }

  /// Cancels every PillBreakfast-namespaced pending request and schedules a fresh set.
  @MainActor
  public static func rebuildAll(
    from snapshot: RegimenSnapshot,
    center: UNUserNotificationCenter = .current()
  ) async {
    let pending = await center.pendingNotificationRequests()
    let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
    center.removePendingNotificationRequests(withIdentifiers: stale)

    let requests = makeRequests(from: snapshot)
    if requests.count > systemPendingLimit {
      logger.warning("Scheduling \(requests.count) reminders exceeds the watchOS pending limit (\(systemPendingLimit)); extras will be dropped by the system.")
    }
    for request in requests {
      do {
        try await center.add(request)
      } catch {
        // One request failing must not abort the rest of the rebuild — but log it
        // so a silent failure (e.g. hitting the per-app ceiling) is visible.
        logger.warning("Failed to schedule \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  // MARK: - Helpers

  private struct TimeSlot: Hashable {
    let hour: Int
    let minute: Int
  }

  /// Key under which `makeContent` stashes the resolved display label for
  /// the slot. `public` so consumers in the watch target — and in
  /// `Shared/` once it ships as its own package — read from the same
  /// constant and the schedule→delegate round-trip can't drift on a key typo.
  public static let medicationNameUserInfoKey = "medicationName"

  /// Resolves the medication label for a snooze action. Prefers the
  /// structured `userInfo` value (the schedule-time write) and falls
  /// back to `body` for legacy / hand-scheduled requests that lack the
  /// key — `body` carries the same display string `makeContent` would
  /// have stashed, whereas `title` is the aggregate `"Pills · N to take"`
  /// and would degrade the snooze label. `title` is the last-resort
  /// fallback for the (unlikely) request that lacks both.
  public static func medicationName(from content: UNNotificationContent) -> String {
    if let stored = content.userInfo[medicationNameUserInfoKey] as? String, !stored.isEmpty {
      return stored
    }
    if !content.body.isEmpty { return content.body }
    return content.title
  }

  private static func makeContent(namesAtSlot names: [String]) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "Pills · \(names.count) to take"
    let body = bodyText(for: names)
    content.body = body
    // Snooze-time reschedule reads this rather than the display body. Keeping
    // the structured copy means a future tweak to `bodyText` (a friendlier
    // "Time to take Vitamin D" sentence, say) can't silently flow back onto
    // the rescheduled notification's body.
    content.userInfo[medicationNameUserInfoKey] = body
    content.categoryIdentifier = NotificationCategory.maintenanceDose
    content.sound = .default
    return content
  }

  private static func bodyText(for names: [String]) -> String {
    guard names.count > 2 else { return names.joined(separator: " · ") }
    return names.prefix(2).joined(separator: " · ") + " · +\(names.count - 2) more"
  }

  private static func identifier(for dose: ScheduledDoseDTO, weekday: Int?) -> String {
    guard let weekday else { return "\(identifierPrefix)\(dose.id.uuidString)" }
    return "\(identifierPrefix)\(dose.id.uuidString).\(weekday)"
  }

  /// Recovers the `ScheduledDose` id from one of our reminder identifiers (the
  /// inverse of `identifier(for:weekday:)`) — used when a notification action fires
  /// and we need to know which dose it was for. Returns `nil` for foreign ids.
  public static func scheduledDoseID(fromIdentifier identifier: String) -> UUID? {
    guard identifier.hasPrefix(identifierPrefix) else { return nil }
    // After the prefix: "<uuid>" or "<uuid>.<weekday>". The UUID has no dots.
    let remainder = identifier.dropFirst(identifierPrefix.count)
    let uuidPart = remainder.prefix { $0 != "." }
    return UUID(uuidString: String(uuidPart))
  }

  /// One trigger for a daily dose, or one per ISO weekday when `daysOfWeek` is set.
  private static func makeTriggers(for dose: ScheduledDoseDTO) -> [(trigger: UNCalendarNotificationTrigger, weekday: Int?)] {
    if dose.daysOfWeek.isEmpty {
      var components = DateComponents()
      components.hour = dose.hour
      components.minute = dose.minute
      return [(UNCalendarNotificationTrigger(dateMatching: components, repeats: true), nil)]
    }
    return dose.daysOfWeek.map { isoWeekday in
      var components = DateComponents()
      components.hour = dose.hour
      components.minute = dose.minute
      components.weekday = calendarWeekday(fromISO: isoWeekday)
      return (UNCalendarNotificationTrigger(dateMatching: components, repeats: true), isoWeekday)
    }
  }

  /// SPEC stores ISO weekdays (1 = Mon … 7 = Sun); Calendar uses 1 = Sun … 7 = Sat.
  private static func calendarWeekday(fromISO iso: Int) -> Int {
    iso == 7 ? 1 : iso + 1
  }
}
