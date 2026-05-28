import Foundation
import SwiftData

/// A dose the watch should prompt for right now: a scheduled dose within the
/// active window that hasn't been logged yet today.
public struct PendingDose: Sendable, Hashable, Identifiable {
  /// Per-instance identity so two doses for the same med at the same time/quantity
  /// stay distinct in queues and dedup sets (the selector assigns one per dose).
  public let id: UUID
  public let medicationID: UUID
  public let scheduledFor: Date
  public let quantity: Int

  public init(id: UUID = UUID(), medicationID: UUID, scheduledFor: Date, quantity: Int) {
    self.id = id
    self.medicationID = medicationID
    self.scheduledFor = scheduledFor
    self.quantity = quantity
  }
}

/// Decides which scheduled maintenance doses are due around a given moment and
/// have not been logged yet today.
///
/// Deterministic by design: the caller supplies `now` and the `Calendar`, so the
/// result depends only on its inputs and the store state — never on `Date.now`
/// or `Calendar.current` read internally. That is the testing contract.
public struct PendingQueueSelector: Sendable {
  /// Half-width of the "due now" window in minutes, on each side of the
  /// scheduled time. Default 60 per SPEC §7.1 ("within ± 60 min").
  public let windowMinutes: Int
  /// Injected so the timezone/day boundaries are deterministic in tests;
  /// production passes `.current` (a watch-local feature).
  public let calendar: Calendar

  public init(windowMinutes: Int = 60, calendar: Calendar = .current) {
    self.windowMinutes = windowMinutes
    self.calendar = calendar
  }

  @MainActor
  public func pendingDoses(at now: Date, in context: ModelContext) throws -> [PendingDose] {
    let todayISOWeekday = Self.isoWeekday(fromCalendar: calendar.component(.weekday, from: now))
    let startOfDay = calendar.startOfDay(for: now)

    // Predicate on the indexed `isArchived` only; the `kind` enum filter runs in
    // memory (as NotificationScheduler does) to sidestep #Predicate enum quirks.
    let meds = try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .maintenance }

    var results: [PendingDose] = []
    for med in meds {
      for dose in med.schedule {
        // The scheduled wall-clock time, anchored to today in the injected calendar.
        guard let scheduledToday = calendar.date(
          bySettingHour: dose.hour, minute: dose.minute, second: 0, of: startOfDay
        ) else { continue } // hour/minute doesn't exist today (e.g. DST gap) — skip.

        let deltaMinutes = abs(scheduledToday.timeIntervalSince(now)) / 60
        guard deltaMinutes <= Double(windowMinutes) else { continue }

        // `daysOfWeek` is ISO (Mon = 1 … Sun = 7); empty means every day.
        guard dose.daysOfWeek.isEmpty || dose.daysOfWeek.contains(todayISOWeekday) else { continue }

        // Suppress a slot already logged today (taken or skipped). Match the slot
        // precisely — same day AND same hour:minute — so a twice-daily med's later
        // dose isn't hidden just because the earlier one was logged.
        let alreadyLogged = med.doseEvents.contains { event in
          guard let scheduledFor = event.scheduledFor else { return false } // PRN/unscheduled never matches a slot.
          return calendar.isDate(scheduledFor, equalTo: scheduledToday, toGranularity: .minute)
        }
        guard !alreadyLogged else { continue }

        results.append(PendingDose(
          medicationID: med.id,
          scheduledFor: scheduledToday,
          quantity: dose.quantity
        ))
      }
    }
    return results.sorted { $0.scheduledFor < $1.scheduledFor }
  }

  /// `Calendar`'s `.weekday` is Gregorian (Sun = 1 … Sat = 7); the schedule stores
  /// ISO weekdays (Mon = 1 … Sun = 7). This is the inverse of
  /// `NotificationScheduler.calendarWeekday(fromISO:)`.
  static func isoWeekday(fromCalendar gregorian: Int) -> Int {
    gregorian == 1 ? 7 : gregorian - 1
  }
}
