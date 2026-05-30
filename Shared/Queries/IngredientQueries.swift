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
  /// Implementation: paged descending scan with `pageSize` events per fetch,
  /// stopping at the first match. Bounds memory to one page (~100 events) in
  /// the common case while still finding far-back matches if the most recent
  /// events are all `.skipped` / `.snoozed` / for-other-ingredients. The
  /// `takenAt` index makes each page cheap.
  public static func lastDoseTime(
    ingredient: Ingredient,
    in context: ModelContext,
    atOrBefore now: Date
  ) throws -> Date? {
    let ingredientID = ingredient.id
    return try pagedScan(in: context, atOrBefore: now) { event in
      event.status == .taken
        && event.ingredientAmounts.contains { $0.ingredientID == ingredientID }
    }
  }

  /// The most recent `.taken` time this **product** was logged, at or before `now`.
  ///
  /// Per-*product* (by medication), unlike `lastDoseTime` which is per-ingredient:
  /// PRN row labels show when this product was last taken, while safety checks
  /// aggregate by ingredient (SPEC §7.3). Uses the same paged descending scan
  /// as `lastDoseTime` — bounded memory, correct far-back lookup.
  public static func lastProductDoseTime(
    medication: Medication,
    in context: ModelContext,
    atOrBefore now: Date
  ) throws -> Date? {
    let medicationID = medication.id
    return try pagedScan(in: context, atOrBefore: now) { event in
      event.status == .taken && event.medication?.id == medicationID
    }
  }

  /// Page size for the descending-history scan. 100 covers Geoff's ~12-pills-
  /// per-day budget across 8 days — typically more than enough to find a
  /// recent match in a single page without materializing the full history.
  /// `public` so tests can drive the boundary deterministically.
  public static let pageSize: Int = 100

  /// Descending paged scan over `DoseEvent`s with `takenAt <= now`, stopping
  /// at the first event for which `match` returns true. Returns its
  /// `takenAt`, or `nil` if no match is found across the whole history.
  ///
  /// Bounds memory to one page at a time. Correctness vs. the old unbounded
  /// scan is preserved because the order is stable (`SortDescriptor` on the
  /// indexed `takenAt`) and the scan terminates only when a page comes back
  /// shorter than `pageSize` (i.e., we've reached the oldest events).
  private static func pagedScan(
    in context: ModelContext,
    atOrBefore now: Date,
    match: (DoseEvent) -> Bool
  ) throws -> Date? {
    var offset = 0
    while true {
      var descriptor = FetchDescriptor<DoseEvent>(
        predicate: #Predicate { $0.takenAt <= now }
      )
      descriptor.sortBy = [SortDescriptor(\.takenAt, order: .reverse)]
      descriptor.fetchLimit = pageSize
      descriptor.fetchOffset = offset
      let page = try context.fetch(descriptor)
      if let hit = page.first(where: match) {
        return hit.takenAt
      }
      // Last page is signaled by a short read — anything else means there's
      // more history to walk.
      if page.count < pageSize {
        return nil
      }
      offset += page.count
    }
  }
}
