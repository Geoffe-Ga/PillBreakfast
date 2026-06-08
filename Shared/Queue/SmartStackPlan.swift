import Foundation

/// Pure grouping for the Smart Stack widget: collapses a day's active maintenance
/// doses into Pill-Meal / time-slot groups. In `Shared/` so it's CI-tested without
/// a widget test target.
public enum SmartStackPlan {
  /// A value snapshot of one dose group — safe to cross out of the `ModelContext`.
  public struct DoseGroupSummary: Sendable, Hashable {
    public let groupName: String
    public let doseCount: Int
    public let scheduledAt: Date
    public let containsHighRisk: Bool

    public init(groupName: String, doseCount: Int, scheduledAt: Date, containsHighRisk: Bool) {
      self.groupName = groupName
      self.doseCount = doseCount
      self.scheduledAt = scheduledAt
      self.containsHighRisk = containsHighRisk
    }
  }

  private struct TimeSlotKey: Hashable {
    let hour: Int
    let minute: Int
  }

  private struct Bucket {
    var names: [String] = []
    var count = 0
    var highRisk = false
    let hour: Int
    let minute: Int
    let mealName: String?
  }

  /// Groups `day`'s active maintenance doses: by Pill Meal (anchored at the
  /// meal's target time), else by time slot for ungrouped doses. Honors
  /// `daysOfWeek`, DST-guards the anchor with `continue`, returns time-sorted.
  public static func doseGroups(
    maintenanceMeds meds: [Medication],
    on day: Date,
    calendar: Calendar
  ) -> [DoseGroupSummary] {
    let gregorian = calendar.component(.weekday, from: day)
    let isoWeekday = gregorian == 1 ? 7 : gregorian - 1

    var mealBuckets: [UUID: Bucket] = [:]
    var slotBuckets: [TimeSlotKey: Bucket] = [:]

    for med in meds {
      for dose in med.schedule {
        if !dose.daysOfWeek.isEmpty, !dose.daysOfWeek.contains(isoWeekday) { continue }
        if let meal = dose.pillMeal {
          var bucket = mealBuckets[meal.id]
            ?? Bucket(hour: meal.targetHour, minute: meal.targetMinute, mealName: meal.name)
          bucket.names.append(med.displayName)
          bucket.count += 1
          bucket.highRisk = bucket.highRisk || med.isHighRisk
          mealBuckets[meal.id] = bucket
        } else {
          let key = TimeSlotKey(hour: dose.hour, minute: dose.minute)
          var bucket = slotBuckets[key] ?? Bucket(hour: dose.hour, minute: dose.minute, mealName: nil)
          bucket.names.append(med.displayName)
          bucket.count += 1
          bucket.highRisk = bucket.highRisk || med.isHighRisk
          slotBuckets[key] = bucket
        }
      }
    }

    let buckets = Array(mealBuckets.values) + Array(slotBuckets.values)
    return buckets
      .compactMap { bucket -> DoseGroupSummary? in
        guard let scheduledAt = calendar.date(
          bySettingHour: bucket.hour,
          minute: bucket.minute,
          second: 0,
          of: day
        ) else { return nil }
        return DoseGroupSummary(
          groupName: bucket.mealName ?? groupLabel(bucket.names),
          doseCount: bucket.count,
          scheduledAt: scheduledAt,
          containsHighRisk: bucket.highRisk
        )
      }
      .sorted { $0.scheduledAt < $1.scheduledAt }
  }

  /// ≤2 names joined with " · "; 3+ → first two + " · +N more". Mirrors
  /// `NotificationScheduler.bodyText(for:)` so the widget and notification read
  /// the same way.
  public static func groupLabel(_ names: [String]) -> String {
    guard names.count > 2 else { return names.joined(separator: " · ") }
    return names.prefix(2).joined(separator: " · ") + " · +\(names.count - 2) more"
  }
}
