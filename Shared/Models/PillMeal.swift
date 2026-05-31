import Foundation
import SwiftData

/// Named time-anchor for grouped notifications (SPEC §5.4 `plans/2026-05-31_PILL_MEALS.md`). No tolerance fields — compliance is count-based.
@Model
public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String
  // Editor (#190) enforces 0…23 / 0…59 via DatePicker; model-layer clamp tracked in #199.
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
    self.id = id
    self.name = name
    self.targetHour = targetHour
    self.targetMinute = targetMinute
    self.sortOrder = sortOrder
    self.createdAt = createdAt
  }

  /// Updates `targetHour` / `targetMinute` AND rewrites every assigned dose's
  /// hour/minute when the time actually changed. Meal owns the time once a
  /// dose is assigned to it, so the propagation belongs on the model.
  public func applyTime(targetHour: Int, targetMinute: Int) {
    let changed = self.targetHour != targetHour || self.targetMinute != targetMinute
    self.targetHour = targetHour
    self.targetMinute = targetMinute
    guard changed else { return }
    for dose in scheduledDoses {
      dose.hour = targetHour
      dose.minute = targetMinute
    }
  }
}
