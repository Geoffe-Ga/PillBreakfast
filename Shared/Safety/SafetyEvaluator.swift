import Foundation
import os
import SwiftData

/// Decides whether a prospective dose would violate any ingredient safety rule,
/// aggregating across **every product that shares an ingredient** (SPEC §5.3).
///
/// Pure and side-effect-free: it returns typed `[Violation]` (empty means safe)
/// and never writes a `DoseEvent` or shows UI. The interstitial (EPIC_05_ISSUE_05)
/// calls this before logging.
@MainActor
public enum SafetyEvaluator {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Safety")

  public static func violationsIfTaken(
    _ medication: Medication,
    quantity: Int,
    at now: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> [Violation] {
    var violations: [Violation] = []

    // Aggregate added-mg per ingredient before evaluating thresholds. Combo
    // products (EPIC_05_ISSUE_06) may carry the same ingredient in two
    // components — say a brand acetaminophen alongside an APAP filler — and
    // summing the contributions first is the only way to avoid the
    // safety-relevant under-count of evaluating each component independently.
    for aggregate in aggregatedByIngredient(medication, quantity: quantity) {
      let ingredient = aggregate.ingredient
      let addedMg = aggregate.addedMg

      // Daily ceiling: today's logged total (across all products) plus the dose
      // we're about to take. `>` so a dose landing exactly on the ceiling is allowed.
      if let ceiling = ingredient.dailyCeilingMg {
        let todayMg = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now, calendar: calendar)
        let proposed = todayMg + addedMg
        if proposed > ceiling {
          violations.append(.ceiling(ingredient: ingredient, current: todayMg, proposed: proposed, ceiling: ceiling))
        }
      }

      // Minimum interval: how long since this ingredient was last taken.
      // Dose-amount-independent, so the per-ingredient grouping doesn't change
      // its semantics — but evaluating once per ingredient prevents a duplicate
      // `.tooSoon` entry when the same ingredient appears in two components.
      if let minInterval = ingredient.minIntervalMinutes,
         let lastDose = try IngredientQueries.lastDoseTime(ingredient: ingredient, in: context, atOrBefore: now),
         now.timeIntervalSince(lastDose) < Double(minInterval * 60)
      {
        violations.append(.tooSoon(ingredient: ingredient, lastTakenAt: lastDose, minInterval: minInterval))
      }
    }

    return violations
  }

  /// Per-ingredient bundle: the canonical `Ingredient` reference plus the
  /// summed `quantity × dosagePerUnitMg` across every component of
  /// `medication` that points at that ingredient.
  private struct IngredientAggregate {
    let ingredient: Ingredient
    let addedMg: Double
  }

  /// Group `medication.components` by `ingredient.id`, summing the
  /// contributions. A component without an ingredient is a data-integrity
  /// fault — logged loudly and skipped, because for a safety gate a check
  /// that silently doesn't fire because of missing data is worse than a
  /// false positive.
  ///
  /// Returned in ingredient-name order so the resulting `Violation` list is
  /// deterministic across runs (existing tests don't lean on order, but a
  /// stable order is the cheaper invariant).
  private static func aggregatedByIngredient(
    _ medication: Medication,
    quantity: Int
  ) -> [IngredientAggregate] {
    var sumByID: [UUID: Double] = [:]
    var ingredientByID: [UUID: Ingredient] = [:]
    for component in medication.components {
      guard let ingredient = component.ingredient else {
        logger.warning("Component \(component.id, privacy: .public) has no ingredient; cannot safety-check it.")
        continue
      }
      sumByID[ingredient.id, default: 0] += Double(quantity) * component.dosagePerUnitMg
      ingredientByID[ingredient.id] = ingredient
    }
    return sumByID.compactMap { id, sum -> IngredientAggregate? in
      guard let ingredient = ingredientByID[id] else { return nil }
      return IngredientAggregate(ingredient: ingredient, addedMg: sum)
    }.sorted { $0.ingredient.name < $1.ingredient.name }
  }
}
