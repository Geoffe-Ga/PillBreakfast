import Foundation
import SwiftData

/// Aggregate read for the History tab's per-day drill-down (SPEC §6.2). All
/// fields are value types so the summary can cross actor boundaries; the live
/// `DoseEvent`s themselves are fetched separately by the drill-down view.
public struct DailySummary: Sendable, Hashable {
  public let day: Date
  public let totalCount: Int
  public let takenCount: Int
  public let skippedCount: Int
  public let snoozedCount: Int
  /// Per-ingredient totals aggregated across every `.taken` event for the day,
  /// sorted by ingredient name for deterministic display. Built from the
  /// denormalized `DoseEvent.ingredientAmounts` snapshots so editing a
  /// medication's components later does not rewrite history (SPEC §5.3).
  public let ingredientTotals: [LoggedIngredientAmount]

  public init(
    day: Date,
    totalCount: Int,
    takenCount: Int,
    skippedCount: Int,
    snoozedCount: Int,
    ingredientTotals: [LoggedIngredientAmount]
  ) {
    self.day = day
    self.totalCount = totalCount
    self.takenCount = takenCount
    self.skippedCount = skippedCount
    self.snoozedCount = snoozedCount
    self.ingredientTotals = ingredientTotals
  }
}

/// Errors `HistoryQueries` raises when the inputs themselves are wrong (vs. a
/// SwiftData fetch error, which propagates as-is).
public enum HistoryQueriesError: Error, Sendable {
  /// `Calendar` failed to produce the day-after `startOfDay`. Extremely rare —
  /// only seen in malformed calendar identifiers — but explicitly raised
  /// rather than falling back to an impossible `startOfDay ..< startOfDay`
  /// range that would silently return zero events.
  case calendarArithmeticFailed
}

/// Pure read helpers for the History tab. Like `IngredientQueries`, these read
/// the denormalized `DoseEvent.ingredientAmounts` snapshots so the totals
/// reflect what was actually logged, not the live product graph.
@MainActor
public enum HistoryQueries {
  /// Aggregate dose events in `day`'s calendar day. Status counts cover every
  /// event in the window; ingredient totals roll up `.taken` events only —
  /// `.skipped` and `.snoozed` doses never reached the body, so their
  /// ingredients are not added to the day's running totals.
  public static func dailySummary(
    in context: ModelContext,
    day: Date,
    calendar: Calendar = .current,
    medicationID: UUID? = nil
  ) throws -> DailySummary {
    let startOfDay = calendar.startOfDay(for: day)
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      throw HistoryQueriesError.calendarArithmeticFailed
    }
    // `takenAt` ascending so the aggregation loop's "first-seen ingredient
    // name wins" rule is deterministic across fetches.
    let descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate {
        $0.takenAt >= startOfDay
          && $0.takenAt < nextDay
          && (medicationID == nil || $0.medication?.id == medicationID)
      },
      sortBy: [SortDescriptor(\DoseEvent.takenAt)]
    )
    let events = try context.fetch(descriptor)

    let taken = events.filter { $0.status == .taken }
    let skipped = events.filter { $0.status == .skipped }
    let snoozed = events.filter { $0.status == .snoozed }

    // Aggregate ingredient totals by ID. Each amount carries its own name and
    // mg; if the same ingredient appears across multiple `.taken` events on
    // the day, sum their mg and keep the earliest snapshot's name (the fetch
    // is sorted by `takenAt` ascending). A user renaming an ingredient mid-day
    // therefore renders under the older name until the calendar day rolls
    // over — documented edge case for a future cleanup.
    var totalsByID: [UUID: LoggedIngredientAmount] = [:]
    for event in taken {
      for amount in event.ingredientAmounts {
        if let existing = totalsByID[amount.ingredientID] {
          totalsByID[amount.ingredientID] = LoggedIngredientAmount(
            ingredientID: amount.ingredientID,
            ingredientName: existing.ingredientName,
            totalMg: existing.totalMg + amount.totalMg
          )
        } else {
          totalsByID[amount.ingredientID] = amount
        }
      }
    }
    let ingredientTotals = totalsByID.values.sorted { $0.ingredientName < $1.ingredientName }

    return DailySummary(
      day: startOfDay,
      totalCount: events.count,
      takenCount: taken.count,
      skippedCount: skipped.count,
      snoozedCount: snoozed.count,
      ingredientTotals: ingredientTotals
    )
  }
}
