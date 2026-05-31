import Foundation

/// Picks the quantity for a "log anytime" maintenance dose: the earliest
/// scheduled dose by time-of-day, falling back to 1 when the schedule is empty.
/// Earliest-by-time matches what the user is most likely proactively logging
/// (the morning routine), independent of insertion order.
public enum AnytimeLogQuantity {
  public static func defaultQuantity(for medication: Medication) -> Int {
    medication.schedule.min { lhs, rhs in
      lhs.hour * 60 + lhs.minute < rhs.hour * 60 + rhs.minute
    }?.quantity ?? 1
  }
}
