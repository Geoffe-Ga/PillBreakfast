import Foundation
import SwiftData

/// Tracks how many times a single scheduled occurrence has been snoozed today, so
/// the fourth snooze can surface a soft "skip instead?" warning (SPEC §8.3).
///
/// Separate from `DoseEvent` deliberately: a `DoseEvent` only exists once a dose is
/// taken/skipped, but a *snoozed* dose has no event yet. The identity is the
/// scheduled occurrence — `(scheduledDoseID, calendarDay)` — not the medication, so
/// snoozing today's 8 AM dose never affects tomorrow's.
@Model
public final class SnoozeRecord {
  @Attribute(.unique) public var id: UUID
  public var scheduledDoseID: UUID
  public var calendarDay: Date // start of day in the user's calendar
  public var count: Int
  public var lastSnoozedAt: Date

  /// `count` has no default — the only valid initial value is 1 (the first
  /// snooze), and a defaulted 0 would model an "empty" record state that
  /// `SnoozeRecordStore.increment` (the sole inserter) never produces.
  public init(
    id: UUID = UUID(),
    scheduledDoseID: UUID,
    calendarDay: Date,
    count: Int,
    lastSnoozedAt: Date = .now
  ) {
    self.id = id
    self.scheduledDoseID = scheduledDoseID
    self.calendarDay = calendarDay
    self.count = count
    self.lastSnoozedAt = lastSnoozedAt
  }
}
