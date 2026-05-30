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
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      // Throwing rather than `?? startOfDay`: a zero-width window would silently
      // collapse the "already logged" lookup and resurface every slot.
      throw CalendarError.windowComputationFailed
    }

    // Predicate on the indexed `isArchived` only; the `kind` enum filter runs in
    // memory (as NotificationScheduler does) to sidestep #Predicate enum quirks.
    let meds = try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .maintenance }

    // Single bounded fetch of today's already-logged slots, then an O(1)
    // lookup per scheduled slot. Replaces a per-slot
    // `med.doseEvents.contains(...)` that hydrated *every* historical
    // `DoseEvent` for each medication — the exact cascading-fetch hazard
    // SPEC §5.2 calls out (and why `ingredientAmounts` is denormalized).
    let loggedSlots = try Self.loggedSlotKeys(
      in: context,
      startOfDay: startOfDay,
      nextDay: nextDay,
      calendar: calendar
    )

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

        // O(1) lookup in the pre-fetched slot set. The day is implicit in the
        // fetch predicate (`scheduledFor` in `[startOfDay, nextDay)`), so the
        // key only carries `(medicationID, hour, minute)` — a twice-daily
        // med's later dose isn't hidden just because the earlier one was
        // logged.
        let slotKey = SlotKey(medicationID: med.id, hour: dose.hour, minute: dose.minute)
        guard !loggedSlots.contains(slotKey) else { continue }

        results.append(PendingDose(
          medicationID: med.id,
          scheduledFor: scheduledToday,
          quantity: dose.quantity
        ))
      }
    }
    return results.sorted { $0.scheduledFor < $1.scheduledFor }
  }

  /// Bounded by `takenAt` (which is indexed) rather than `scheduledFor`
  /// because `#Predicate` doesn't support the optional force-unwrap pattern
  /// — `event.scheduledFor != nil && event.scheduledFor! >= …` compiles but
  /// fails at fetch time with `unsupportedPredicate` on iOS 26's SwiftData.
  ///
  /// The takenAt window spans `[yesterday-start, day-after-tomorrow-start)`
  /// so a proactively-logged dose (taken late yesterday for today's slot, or
  /// taken in the early morning for the next-day rollover edge) is still
  /// captured. At the documented ~12 pills/day budget the worst-case fetch is
  /// ~36 events, which is the bound the SPEC §5.2 cascading-fetch hazard
  /// demands. `scheduledFor` is then filtered in memory to today's window
  /// before building the SlotKey index.
  @MainActor
  private static func loggedSlotKeys(
    in context: ModelContext,
    startOfDay: Date,
    nextDay: Date,
    calendar: Calendar
  ) throws -> Set<SlotKey> {
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay),
          let dayAfter = calendar.date(byAdding: .day, value: 1, to: nextDay)
    else {
      throw CalendarError.windowComputationFailed
    }
    let descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { event in
        event.takenAt >= yesterday && event.takenAt < dayAfter
      }
    )
    let events = try context.fetch(descriptor)
    var keys: Set<SlotKey> = []
    for event in events {
      guard let scheduledFor = event.scheduledFor,
            scheduledFor >= startOfDay,
            scheduledFor < nextDay,
            let medicationID = event.medication?.id else { continue }
      let components = calendar.dateComponents([.hour, .minute], from: scheduledFor)
      guard let hour = components.hour, let minute = components.minute else { continue }
      keys.insert(SlotKey(medicationID: medicationID, hour: hour, minute: minute))
    }
    return keys
  }

  /// Identity for the "already-logged today" lookup. The day is implicit in
  /// the bounded fetch the keys come from; carrying it would be redundant.
  struct SlotKey: Hashable {
    let medicationID: UUID
    let hour: Int
    let minute: Int
  }

  public enum CalendarError: Error {
    /// `Calendar.date(byAdding: .day, …)` returned `nil` for the day-boundary
    /// math. Effectively impossible on the watchOS 26 Gregorian calendar, but
    /// throwing rather than falling back keeps a degenerate-window from
    /// silently resurfacing every slot.
    case windowComputationFailed
  }

  /// `Calendar`'s `.weekday` is Gregorian (Sun = 1 … Sat = 7); the schedule stores
  /// ISO weekdays (Mon = 1 … Sun = 7). This is the inverse of
  /// `NotificationScheduler.calendarWeekday(fromISO:)`.
  static func isoWeekday(fromCalendar gregorian: Int) -> Int {
    gregorian == 1 ? 7 : gregorian - 1
  }
}
