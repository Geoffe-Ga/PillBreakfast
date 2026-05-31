import Foundation
import SwiftData

@Model
public final class ScheduledDose {
  @Attribute(.unique) public var id: UUID
  public var hour: Int // 0..23
  public var minute: Int // 0..59
  public var quantity: Int // number of pills
  public var daysOfWeek: [Int] // 1..7, ISO weekday; empty = every day
  public var medication: Medication?
  /// Optional Pill Meal grouping. `nil` for legacy rows and for doses the
  /// user hasn't assigned to a meal — both produce the existing per-`TimeSlot`
  /// notification + ungrouped tap-through card behavior. The editor introduces
  /// non-nil assignments in a later issue.
  ///
  /// `.nullify` matches SwiftData's default for optional relationships but is
  /// stated explicitly to match the rest of the schema and document intent.
  /// Inverse is declared on `PillMeal.scheduledDoses`.
  @Relationship(deleteRule: .nullify)
  public var pillMeal: PillMeal?

  public init(
    id: UUID = UUID(),
    hour: Int,
    minute: Int,
    quantity: Int,
    daysOfWeek: [Int] = [],
    medication: Medication? = nil,
    pillMeal: PillMeal? = nil
  ) {
    self.id = id
    self.hour = hour
    self.minute = minute
    self.quantity = quantity
    self.daysOfWeek = daysOfWeek
    self.medication = medication
    self.pillMeal = pillMeal
  }
}
