import Foundation
import SwiftData

/// Decides whether a prospective dose would violate any ingredient safety rule,
/// aggregating across **every product that shares an ingredient** (SPEC §5.3).
///
/// Pure and side-effect-free: it returns typed `[Violation]` (empty means safe)
/// and never writes a `DoseEvent` or shows UI. The interstitial (EPIC_05_ISSUE_05)
/// calls this before logging.
@MainActor
public enum SafetyEvaluator {
  public static func violationsIfTaken(
    _ medication: Medication,
    quantity: Int,
    at now: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> [Violation] {
    var violations: [Violation] = []

    for component in medication.components {
      guard let ingredient = component.ingredient else { continue }
      let addedMg = Double(quantity) * component.dosagePerUnitMg

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
      if let minInterval = ingredient.minIntervalMinutes,
         let lastDose = try IngredientQueries.lastDoseTime(ingredient: ingredient, in: context, atOrBefore: now),
         now.timeIntervalSince(lastDose) < Double(minInterval * 60)
      {
        violations.append(.tooSoon(ingredient: ingredient, lastTakenAt: lastDose, minInterval: minInterval))
      }
    }

    return violations
  }
}
