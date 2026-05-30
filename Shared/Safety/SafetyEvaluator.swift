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

    // Aggregate per ingredient so combo products (#109) don't under-count.
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

  /// Group components by ingredient and sum their contributions; sorted by ingredient name for deterministic violation order.
  private static func aggregatedByIngredient(
    _ medication: Medication,
    quantity: Int
  ) -> [IngredientAggregate] {
    var aggregates: [UUID: IngredientAggregate] = [:]
    for component in medication.components {
      guard let ingredient = component.ingredient else {
        // For a safety gate a check that silently doesn't fire because of
        // missing data is worse than a false positive — log loudly + skip.
        logger.warning("Component \(component.id, privacy: .public) has no ingredient; cannot safety-check it.")
        continue
      }
      let addedMg = Double(quantity) * component.dosagePerUnitMg
      if let existing = aggregates[ingredient.id] {
        aggregates[ingredient.id] = IngredientAggregate(
          ingredient: existing.ingredient,
          addedMg: existing.addedMg + addedMg
        )
      } else {
        aggregates[ingredient.id] = IngredientAggregate(ingredient: ingredient, addedMg: addedMg)
      }
    }
    return aggregates.values.sorted { $0.ingredient.name < $1.ingredient.name }
  }
}
