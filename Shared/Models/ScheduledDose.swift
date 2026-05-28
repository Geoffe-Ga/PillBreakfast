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

  public init(
    id: UUID = UUID(),
    hour: Int,
    minute: Int,
    quantity: Int,
    daysOfWeek: [Int] = [],
    medication: Medication? = nil
  ) {
    self.id = id
    self.hour = hour
    self.minute = minute
    self.quantity = quantity
    self.daysOfWeek = daysOfWeek
    self.medication = medication
  }
}
