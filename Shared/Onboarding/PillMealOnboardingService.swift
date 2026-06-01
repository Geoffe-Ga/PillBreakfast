import Foundation

/// A proposed Pill Meal generated from the user's existing schedule. Pure value
/// type — it carries the cluster's dose IDs so the next-issue persistence step
/// can resolve them back to live `ScheduledDose` rows.
public struct SuggestedMeal: Sendable, Hashable, Identifiable {
  public let id: UUID
  public let suggestedName: String
  public let hour: Int
  public let minute: Int
  public let doseIDs: [UUID]

  public init(
    id: UUID = UUID(),
    suggestedName: String,
    hour: Int,
    minute: Int,
    doseIDs: [UUID]
  ) {
    self.id = id
    self.suggestedName = suggestedName
    self.hour = hour
    self.minute = minute
    self.doseIDs = doseIDs
  }
}

/// Clusters `ScheduledDose` rows by wall-clock time so the first-launch
/// onboarding sheet can propose Pill Meals (SPEC §8.1). Pure / testable — the
/// caller supplies the doses and the calendar; the helper neither fetches nor
/// persists.
public enum PillMealOnboardingService {
  /// Half-width of a cluster in minutes. Two doses fall in the same cluster
  /// when their wall-clock times are ≤ 30 min apart (the spec's tolerance for
  /// "this dose looks like it belongs to that meal").
  public static let clusterWindowMinutes = 30

  /// Minimum doses required to surface a suggestion. Singletons are noise.
  public static let minimumClusterSize = 2

  public static func suggestions(
    from doses: [ScheduledDose],
    calendar _: Calendar = .current
  ) -> [SuggestedMeal] {
    let sorted = doses.sorted { lhs, rhs in
      lhs.hour * 60 + lhs.minute < rhs.hour * 60 + rhs.minute
    }
    var clusters: [[ScheduledDose]] = []
    var current: [ScheduledDose] = []
    var lastMinute = Int.min
    for dose in sorted {
      let minute = dose.hour * 60 + dose.minute
      if current.isEmpty || minute - lastMinute <= clusterWindowMinutes {
        current.append(dose)
      } else {
        clusters.append(current)
        current = [dose]
      }
      lastMinute = minute
    }
    if !current.isEmpty { clusters.append(current) }

    return clusters.compactMap { cluster -> SuggestedMeal? in
      guard cluster.count >= minimumClusterSize, let first = cluster.first else { return nil }
      return SuggestedMeal(
        suggestedName: suggestedName(forHour: first.hour, minute: first.minute),
        hour: first.hour,
        minute: first.minute,
        doseIDs: cluster.map(\.id)
      )
    }
  }

  /// Heuristic name from the cluster's anchor hour. Off-hours fall through to
  /// `"Pill Meal at HH:MM"` so the user can rename in the editor without
  /// staring at a generic label.
  static func suggestedName(forHour hour: Int, minute: Int) -> String {
    switch hour {
    case 5 ..< 11: "Pill Breakfast"
    case 11 ..< 16: "Pill Lunch"
    case 16 ..< 22: "Pill Dinner"
    default: String(format: "Pill Meal at %d:%02d", hour, minute)
    }
  }
}
