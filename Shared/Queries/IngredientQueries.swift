import Foundation
import SwiftData

/// Pure read helpers the ingredient-safety system rests on. Both read from the
/// **denormalized** `DoseEvent.ingredientAmounts` snapshots — never from the live
/// `medication.components` graph — so re-running them after a product is later
/// re-composed still returns the same historical totals (SPEC §5.3, CLAUDE.md).
///
/// Only `.taken` events contribute; `.skipped` / `.snoozed` do not. "Today" is the
/// caller's local calendar day, injected for deterministic tests.
@MainActor
public enum IngredientQueries {
  /// Total mg of `ingredient` consumed in `now`'s calendar day, up to `now`.
  public static func totalToday(
    ingredient: Ingredient,
    in context: ModelContext,
    at now: Date,
    calendar: Calendar = .current
  ) throws -> Double {
    let startOfDay = calendar.startOfDay(for: now)
    // Predicate on the indexed `takenAt` only; `status` is filtered in Swift to
    // avoid #Predicate enum-comparison pitfalls (consistent with the rest of the
    // codebase). The `takenAt` index keeps this range fetch off a full scan.
    let descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { $0.takenAt >= startOfDay && $0.takenAt <= now }
    )
    let ingredientID = ingredient.id
    return try context.fetch(descriptor)
      .filter { $0.status == .taken }
      .flatMap(\.ingredientAmounts)
      .filter { $0.ingredientID == ingredientID }
      .reduce(0) { $0 + $1.totalMg }
  }

  /// The most recent `.taken` time at or before `now` whose dose included
  /// `ingredient`, or `nil` if there is none.
  public static func lastDoseTime(
    ingredient: Ingredient,
    in context: ModelContext,
    before now: Date
  ) throws -> Date? {
    var descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { $0.takenAt <= now }
    )
    descriptor.sortBy = [SortDescriptor(\.takenAt, order: .reverse)]
    let ingredientID = ingredient.id
    return try context.fetch(descriptor)
      .first { event in
        event.status == .taken
          && event.ingredientAmounts.contains { $0.ingredientID == ingredientID }
      }?
      .takenAt
  }
}
