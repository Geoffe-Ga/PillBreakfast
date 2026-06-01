import Foundation
import SwiftData

/// A proposed Pill Meal generated from the user's existing schedule. Pure value
/// type — it carries the cluster's dose IDs so the persistence step can resolve
/// them back to live `ScheduledDose` rows, plus the deduped medication names
/// for the read-only display in the onboarding row.
public struct SuggestedMeal: Sendable, Hashable, Identifiable {
  public let id: UUID
  public let suggestedName: String
  public let hour: Int
  public let minute: Int
  public let doseIDs: [UUID]
  /// Distinct display names of the medications in this cluster, in encounter
  /// order. Display-only — persistence resolves `doseIDs`, not these.
  public let medicationNames: [String]

  public init(
    id: UUID = UUID(),
    suggestedName: String,
    hour: Int,
    minute: Int,
    doseIDs: [UUID],
    medicationNames: [String] = []
  ) {
    self.id = id
    self.suggestedName = suggestedName
    self.hour = hour
    self.minute = minute
    self.doseIDs = doseIDs
    self.medicationNames = medicationNames
  }
}

/// Failure modes for materialising a `SuggestedMeal`.
public enum PillMealOnboardingError: Error, Equatable {
  /// The (trimmed) meal name was empty — the UI disables Save in this case;
  /// this guards the model layer against a blank name slipping through.
  case blankName
}

/// Clusters `ScheduledDose` rows by wall-clock time so the first-launch
/// onboarding sheet can propose Pill Meals (SPEC §8.1), and materialises an
/// accepted suggestion into a persisted `PillMeal`. `suggestions(from:)` is
/// pure; `persist(_:in:)` is the only method that touches the store.
public enum PillMealOnboardingService {
  /// Half-width of a cluster in minutes. Two doses fall in the same cluster
  /// when their wall-clock times are ≤ 30 min apart (the spec's tolerance for
  /// "this dose looks like it belongs to that meal").
  public static let clusterWindowMinutes = 30

  /// Minimum doses required to surface a suggestion. Singletons are noise.
  public static let minimumClusterSize = 2

  public static func suggestions(
    from doses: [ScheduledDose]
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
      let medicationNames = cluster.reduce(into: [String]()) { names, dose in
        guard let name = dose.medication?.displayName, !names.contains(name) else { return }
        names.append(name)
      }
      return SuggestedMeal(
        suggestedName: suggestedName(forHour: first.hour, minute: first.minute),
        hour: first.hour,
        minute: first.minute,
        doseIDs: cluster.map(\.id),
        medicationNames: medicationNames
      )
    }
  }

  /// Materialises a `SuggestedMeal` into a persisted `PillMeal`, assigning the
  /// cluster's `ScheduledDose`s to it. Resolves `doseIDs` against `context` so
  /// the caller never threads live model objects through the value type. Uses
  /// `suggestion.suggestedName` as the meal name — the sheet rebuilds the
  /// suggestion with the user's edited name before calling this. Appends after
  /// any existing meals (`sortOrder = max + 1`). Throws on a blank name or a
  /// save failure; the caller rolls back on throw.
  @MainActor
  @discardableResult
  public static func persist(
    _ suggestion: SuggestedMeal,
    in context: ModelContext
  ) throws -> PillMeal {
    let name = suggestion.suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw PillMealOnboardingError.blankName }

    let doseIDs = suggestion.doseIDs
    let doses = try context.fetch(
      FetchDescriptor<ScheduledDose>(predicate: #Predicate { doseIDs.contains($0.id) })
    )
    // Bounded fetch — only the current max sortOrder is needed, not every meal.
    var orderDescriptor = FetchDescriptor<PillMeal>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
    orderDescriptor.fetchLimit = 1
    let nextOrder = try (context.fetch(orderDescriptor).first?.sortOrder ?? -1) + 1

    let meal = PillMeal(
      name: name,
      targetHour: suggestion.hour,
      targetMinute: suggestion.minute,
      sortOrder: nextOrder
    )
    context.insert(meal)
    for dose in doses {
      dose.pillMeal = meal
    }
    try context.save()
    return meal
  }

  /// Heuristic name from the cluster's anchor hour. Off-hours fall through to
  /// `"Pill Meal at HH:MM"` so the user can rename in the editor without
  /// staring at a generic label.
  public static func suggestedName(forHour hour: Int, minute: Int) -> String {
    switch hour {
    case 5 ..< 11: "Pill Breakfast"
    case 11 ..< 16: "Pill Lunch"
    case 16 ..< 22: "Pill Dinner"
    default: String(format: "Pill Meal at %d:%02d", hour, minute)
    }
  }
}
