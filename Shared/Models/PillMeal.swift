import Foundation
import SwiftData

/// Named time-anchor for grouped notifications (SPEC §5.4 `plans/2026-05-31_PILL_MEALS.md`). No tolerance fields — compliance is count-based.
@Model
public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String
  // Editor (#190) enforces 0…23 / 0…59 via DatePicker; the model-layer safety net
  // is `clampedTime(hour:minute:)`, applied on every write (init + applyTime).
  public var targetHour: Int
  public var targetMinute: Int
  /// Display order with `createdAt` tie-break so new sortOrder=0 meals don't shuffle.
  public var sortOrder: Int
  public var createdAt: Date
  /// Inverse of `ScheduledDose.pillMeal`; `.nullify` keeps doses alive on meal delete.
  @Relationship(deleteRule: .nullify, inverse: \ScheduledDose.pillMeal)
  public var scheduledDoses: [ScheduledDose] = []

  public init(
    id: UUID = UUID(),
    name: String,
    targetHour: Int,
    targetMinute: Int,
    sortOrder: Int = 0,
    createdAt: Date = .now
  ) {
    let time = Self.clampedTime(hour: targetHour, minute: targetMinute)
    self.id = id
    self.name = name
    self.targetHour = time.hour
    self.targetMinute = time.minute
    self.sortOrder = sortOrder
    self.createdAt = createdAt
  }

  /// Pins an (hour, minute) pair into the valid `DateComponents` ranges
  /// (`0…23` / `0…59`). The model-layer safety net for programmatic construction
  /// and migration: the #190 editor already produces valid values, but an
  /// out-of-range value reaching `NotificationScheduler` (#191) would build an
  /// invalid `DateComponents`. Clamps rather than traps so a bad migrated row
  /// can't crash launch.
  public static func clampedTime(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
    (min(max(hour, 0), 23), min(max(minute, 0), 59))
  }

  /// Updates `targetHour` / `targetMinute` AND rewrites every assigned dose's
  /// hour/minute when the time actually changed. Meal owns the time once a
  /// dose is assigned to it, so the propagation belongs on the model. Inputs are
  /// clamped (`clampedTime`) so this write path enforces the bounds too.
  public func applyTime(targetHour: Int, targetMinute: Int) {
    let time = Self.clampedTime(hour: targetHour, minute: targetMinute)
    let changed = self.targetHour != time.hour || self.targetMinute != time.minute
    self.targetHour = time.hour
    self.targetMinute = time.minute
    guard changed else { return }
    for dose in scheduledDoses {
      dose.hour = time.hour
      dose.minute = time.minute
    }
  }
}
