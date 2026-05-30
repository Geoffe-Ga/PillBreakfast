import Foundation
import SwiftData

/// Reads and updates `SnoozeRecord` counts keyed on a scheduled occurrence
/// `(scheduledDoseID, calendarDay)`. The fourth-snooze warning routes off these.
@MainActor
public enum SnoozeRecordStore {
  /// How many times this occurrence has been snoozed today (0 if never).
  public static func currentCount(
    scheduledDoseID: UUID,
    on day: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> Int {
    try record(scheduledDoseID: scheduledDoseID, on: day, in: context, calendar: calendar)?.count ?? 0
  }

  /// Rows whose `calendarDay` is strictly older than `today - staleHorizonDays`
  /// are deleted; a row at exactly that boundary is **kept**. The retained
  /// window is therefore `staleHorizonDays + 1` days (today plus the prior
  /// `staleHorizonDays`). The fourth-snooze warning only reads today's row, so
  /// 1 would be functionally enough — the extra week is debugging headroom (a
  /// row visible in the store the morning after a regression is much easier to
  /// reason about than one already pruned) and a buffer for DST / timezone
  /// shifts around midnight.
  public static let staleHorizonDays: Int = 7

  /// Bumps the occurrence's count by one (creating the record if needed) and
  /// returns the new count. Also prunes any records older than
  /// `staleHorizonDays` so a long-used medication's history doesn't accumulate
  /// indefinitely. Increment is the natural prune trigger: it's already a
  /// write, runs at most a handful of times per day, and amortizes the
  /// housekeeping over user interaction without a separate background pass.
  @discardableResult
  public static func increment(
    scheduledDoseID: UUID,
    on day: Date,
    at now: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> Int {
    let startOfDay = calendar.startOfDay(for: day)
    try pruneStaleRecords(asOf: startOfDay, in: context, calendar: calendar)
    if let existing = try record(scheduledDoseID: scheduledDoseID, on: day, in: context, calendar: calendar) {
      existing.count += 1
      existing.lastSnoozedAt = now
      try context.save()
      return existing.count
    }
    let record = SnoozeRecord(scheduledDoseID: scheduledDoseID, calendarDay: startOfDay, count: 1, lastSnoozedAt: now)
    context.insert(record)
    try context.save()
    return record.count
  }

  /// Clears the count for this occurrence (e.g. after it's taken or skipped), so a
  /// later occurrence on another day starts fresh and a stale warning can't fire.
  public static func reset(
    scheduledDoseID: UUID,
    on day: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws {
    guard let existing = try record(scheduledDoseID: scheduledDoseID, on: day, in: context, calendar: calendar) else { return }
    context.delete(existing)
    try context.save()
  }

  /// Bulk `delete(model:where:)` so stale rows never materialize into the
  /// store's working set.
  private static func pruneStaleRecords(
    asOf referenceDay: Date,
    in context: ModelContext,
    calendar: Calendar
  ) throws {
    guard let cutoff = calendar.date(byAdding: .day, value: -staleHorizonDays, to: referenceDay) else {
      // Day arithmetic on a valid calendar can't produce nil here; assert in
      // debug so a SDK regression surfaces in tests rather than silently
      // skipping prune in release.
      assertionFailure("calendar.date(byAdding: .day, value: -\(staleHorizonDays), to: \(referenceDay)) returned nil")
      return
    }
    try context.delete(model: SnoozeRecord.self, where: #Predicate { $0.calendarDay < cutoff })
  }

  private static func record(
    scheduledDoseID: UUID,
    on day: Date,
    in context: ModelContext,
    calendar: Calendar
  ) throws -> SnoozeRecord? {
    let startOfDay = calendar.startOfDay(for: day)
    // calendarDay is always stored as calendar.startOfDay(for:) (see increment), so an
    // equality match is exact and pushes the day filter into the fetch instead of memory.
    return try context
      .fetch(FetchDescriptor<SnoozeRecord>(predicate: #Predicate {
        $0.scheduledDoseID == scheduledDoseID && $0.calendarDay == startOfDay
      }))
      .first
  }
}
