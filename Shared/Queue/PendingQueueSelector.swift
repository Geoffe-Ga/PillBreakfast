import Foundation
import SwiftData

/// A dose the watch should prompt for right now: a scheduled dose within the
/// active window that hasn't been logged yet today.
public struct PendingDose: Sendable, Hashable, Identifiable {
  /// 1-based position of a meal's dose within the meal's pending set.
  public struct MealOrdinal: Sendable, Hashable {
    public let current: Int
    public let total: Int

    public init(current: Int, total: Int) {
      self.current = current
      self.total = total
    }
  }

  /// Per-instance identity so two doses for the same med at the same time/quantity
  /// stay distinct in queues and dedup sets (the selector assigns one per dose).
  public let id: UUID
  public let medicationID: UUID
  public let scheduledFor: Date
  public let quantity: Int
  /// Stable id of the meal that owns this dose, when assigned. Nil for ungrouped doses.
  public let mealID: UUID?
  /// User-facing meal name, denormalized at selection time so the watch card
  /// doesn't have to re-traverse the relationship to render the header.
  public let mealName: String?
  /// 1-based position within the meal's pending doses (e.g. "2 of 5").
  /// Nil for ungrouped doses or when the meal has only one dose pending — the
  /// header line only adds context, so a "1 of 1" decoration is suppressed.
  public let mealOrdinal: MealOrdinal?

  public init(
    id: UUID = UUID(),
    medicationID: UUID,
    scheduledFor: Date,
    quantity: Int,
    mealID: UUID? = nil,
    mealName: String? = nil,
    mealOrdinal: MealOrdinal? = nil
  ) {
    self.id = id
    self.medicationID = medicationID
    self.scheduledFor = scheduledFor
    self.quantity = quantity
    self.mealID = mealID
    self.mealName = mealName
    self.mealOrdinal = mealOrdinal
  }
}

/// Decides which scheduled maintenance doses are due around a given moment and
/// have not been logged yet today.
///
/// Deterministic by design: the caller supplies `now` and the `Calendar`, so the
/// result depends only on its inputs and the store state — never on `Date.now`
/// or `Calendar.current` read internally. That is the testing contract.
@MainActor
public struct PendingQueueSelector {
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
          quantity: dose.quantity,
          mealID: dose.pillMeal?.id,
          mealName: dose.pillMeal?.name
        ))
      }
    }
    return Self.assignMealOrdinals(to: results.sorted { $0.scheduledFor < $1.scheduledFor })
  }

  /// Walks the ordered queue, counts each meal's pending doses, and stamps a
  /// 1-based ordinal on each. Internal so the contract can be exercised without
  /// a SwiftData round-trip. Singleton meals (one pending dose) leave
  /// `mealOrdinal == nil` — the header line shows the meal name but not "1 of 1".
  static func assignMealOrdinals(to doses: [PendingDose]) -> [PendingDose] {
    var totals: [UUID: Int] = [:]
    for dose in doses {
      if let mealID = dose.mealID { totals[mealID, default: 0] += 1 }
    }
    var seen: [UUID: Int] = [:]
    return doses.map { dose in
      guard let mealID = dose.mealID, let total = totals[mealID], total > 1 else { return dose }
      let current = (seen[mealID] ?? 0) + 1
      seen[mealID] = current
      return PendingDose(
        id: dose.id,
        medicationID: dose.medicationID,
        scheduledFor: dose.scheduledFor,
        quantity: dose.quantity,
        mealID: dose.mealID,
        mealName: dose.mealName,
        mealOrdinal: PendingDose.MealOrdinal(current: current, total: total)
      )
    }
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
    // `fetchLimit` is a defensive ceiling — the 12-pills/day budget gives
    // ~36 events in a 3-day window, so 200 is comfortably above any
    // realistic load while bounding a schema-drift / test-seed bug from
    // hydrating millions of rows.
    var descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { event in
        event.takenAt >= yesterday && event.takenAt < dayAfter
      }
    )
    descriptor.fetchLimit = Self.fetchLimit
    let events = try context.fetch(descriptor)
    // Fail closed on a truncated fetch: silently returning a partial set
    // would mark previously-logged slots as "not yet logged" and the watch
    // would re-suggest them — a duplicate-log risk on safety-critical meds
    // like lithium. Caller (`pendingDoses`) catches and surfaces as
    // "no pending" via `RightNowView.reload()`'s error path.
    if events.count >= Self.fetchLimit {
      throw CalendarError.fetchLimitReached
    }
    var keys: Set<SlotKey> = []
    for event in events {
      guard let scheduledFor = event.scheduledFor,
            scheduledFor >= startOfDay,
            scheduledFor < nextDay else { continue }
      // Read the denormalized `medicationID` rather than `event.medication?.id`,
      // so this bounded loop never faults a `Medication` row per event. A legacy
      // row whose medication was deleted carries the sentinel id, which never
      // matches a real medication's slot key — harmless.
      let components = calendar.dateComponents([.hour, .minute], from: scheduledFor)
      guard let hour = components.hour, let minute = components.minute else { continue }
      keys.insert(SlotKey(medicationID: event.medicationID, hour: hour, minute: minute))
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

  /// Defensive ceiling on the today-window fetch. Reachable only via schema
  /// drift or pathological test seeding; the production budget (~36 events
  /// in 3 days) is two orders of magnitude below this. Exposed `public` so
  /// callers — and the test suite — can reason about the boundary without
  /// duplicating the constant.
  public static let fetchLimit: Int = 200

  /// `public` so call sites outside `Shared/` can switch on the case rather
  /// than falling back to an opaque `Error` catch — the watch app might want
  /// to surface a "history too large, contact support" message on
  /// `fetchLimitReached` distinct from the silent retry on
  /// `windowComputationFailed`.
  public enum CalendarError: Error {
    /// `Calendar.date(byAdding: .day, …)` returned `nil` for the day-boundary
    /// math. Effectively impossible on the watchOS 26 Gregorian calendar, but
    /// throwing rather than falling back keeps a degenerate-window from
    /// silently resurfacing every slot.
    case windowComputationFailed
    /// The today-window fetch returned `fetchLimit` events. The result set
    /// would be truncated; throwing prevents a partial "already logged"
    /// lookup from silently surfacing duplicate-log opportunities on
    /// safety-critical meds.
    case fetchLimitReached
  }

  /// `Calendar`'s `.weekday` is Gregorian (Sun = 1 … Sat = 7); the schedule stores
  /// ISO weekdays (Mon = 1 … Sun = 7). This is the inverse of
  /// `NotificationScheduler.calendarWeekday(fromISO:)`.
  static func isoWeekday(fromCalendar gregorian: Int) -> Int {
    gregorian == 1 ? 7 : gregorian - 1
  }
}
