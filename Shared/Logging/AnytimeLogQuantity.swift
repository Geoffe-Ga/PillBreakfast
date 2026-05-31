import Foundation

/// Picks the quantity for a "log anytime" maintenance dose: the first
/// scheduled dose's quantity, or 1 when the schedule is empty.
public enum AnytimeLogQuantity {
  public static func defaultQuantity(for medication: Medication) -> Int {
    medication.schedule.first?.quantity ?? 1
  }
}
