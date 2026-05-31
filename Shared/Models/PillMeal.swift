import Foundation
import SwiftData

/// A named, time-anchored grouping of medications the user takes together
/// (SPEC §5.4 — `plans/2026-05-31_PILL_MEALS.md`). The app's namesake
/// concept: "Pill Breakfast" / "Pill Dinner". Meal is organizational — it
/// drives notification title + watch tap-through header — and per-dose
/// confirms (single-tap / press-and-hold) are unchanged.
///
/// **No tolerance / window fields**: the notification fires at the target
/// time; the logged time is recorded but never labelled on-time / late.
/// Compliance is per-day count match (taken vs scheduled).
@Model
public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String
  public var targetHour: Int // 0…23
  public var targetMinute: Int // 0…59
  /// Stable display order in the iPhone Pill Meals section. Defaults to 0
  /// so newly-created meals append; the editor can later expose drag-to-reorder.
  public var sortOrder: Int
  public var createdAt: Date
  /// Inverse of `ScheduledDose.pillMeal`. Lets the editor (next issue) read
  /// `meal.scheduledDoses` directly to gate deletion ("can't delete a meal
  /// with assigned doses") and to summarize "N doses" in the section row.
  /// `.nullify` keeps doses around when the meal is deleted — the editor is
  /// responsible for blocking deletion while assignments exist.
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
}
