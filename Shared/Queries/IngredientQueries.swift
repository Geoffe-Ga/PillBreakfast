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
  /// Total mg of `ingredient` consumed in `now`'s calendar day, **at or before**
  /// `now` (inclusive). This is the amount already logged; a ceiling check should
  /// add the prospective dose on top (`totalToday(at: now) + prospectiveMg`), since
  /// the about-to-be-taken dose isn't in the store yet. Inclusive `<= now` is
  /// deliberate so a dose logged at exactly `now` counts as consumed.
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

  /// The most recent `.taken` time at or before `now` (inclusive) whose dose
  /// included `ingredient`, or `nil` if there is none.
  ///
  /// No `fetchLimit`: the matching event can be arbitrarily far back if the most
  /// recent events are `.skipped`/`.snoozed` or for other ingredients, so a limit
  /// could return a false `nil`. The fetch is `takenAt`-indexed and descending, so
  /// the common case (a recent match) is cheap, but the worst case scans history —
  /// a bounded/indexed implementation is tracked as a follow-up.
  public static func lastDoseTime(
    ingredient: Ingredient,
    in context: ModelContext,
    atOrBefore now: Date
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

  /// The most recent `.taken` time this **product** was logged, at or before `now`.
  ///
  /// Per-*product* (by medication), unlike `lastDoseTime` which is per-ingredient:
  /// PRN row labels show when this product was last taken, while safety checks
  /// aggregate by ingredient (SPEC §7.3). Same unbounded-scan caveat as
  /// `lastDoseTime` (tracked in the bounded-scan follow-up).
  public static func lastProductDoseTime(
    medication: Medication,
    in context: ModelContext,
    atOrBefore now: Date
  ) throws -> Date? {
    var descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { $0.takenAt <= now }
    )
    descriptor.sortBy = [SortDescriptor(\.takenAt, order: .reverse)]
    let medicationID = medication.id
    return try context.fetch(descriptor)
      .first { $0.status == .taken && $0.medication?.id == medicationID }?
      .takenAt
  }
}
