import Foundation
import SwiftData

/// One PRN product's row content for the watch PRN list. Two lines: the product
/// name (`firstLine`), and a today-total / last-dose summary (`secondLine`)
/// whose shape depends on the product variant (SPEC §7.3).
public struct PRNRowSummary: Sendable, Hashable, Identifiable {
  public let medicationID: UUID
  public let firstLine: String
  public let secondLine: String
  /// The ingredient the second line is "about" (the single ingredient, or the
  /// highest-utilization one for a combo) — for an optional accent, nil if none.
  public let highlightedIngredientID: UUID?

  public var id: UUID {
    medicationID
  }

  public init(
    medicationID: UUID,
    firstLine: String,
    secondLine: String,
    highlightedIngredientID: UUID?
  ) {
    self.medicationID = medicationID
    self.firstLine = firstLine
    self.secondLine = secondLine
    self.highlightedIngredientID = highlightedIngredientID
  }
}

/// Builds a `PRNRowSummary` from a `Medication` and the live store, picking the
/// right SPEC §7.3 variant: single-ingredient prescription ("600 mg today"),
/// single-ingredient OTC ("1500 mg acetaminophen today"), or combo ("acetaminophen
/// 38% of daily limit", the highest-utilization ingredient).
@MainActor
public enum PRNRowSummaryBuilder {
  public static func summary(
    for medication: Medication,
    at now: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> PRNRowSummary {
    // Last-dose label is per *product* (SPEC §7.3) — distinct from the per-ingredient
    // aggregation the safety checks use.
    let lastDose = try IngredientQueries.lastProductDoseTime(medication: medication, in: context, atOrBefore: now)
    let lastDoseText = lastDose.map { "last \($0.formatted(date: .omitted, time: .shortened))" } ?? "no doses yet"

    // Single-ingredient product: prescription shows "N mg today"; OTC names the
    // ingredient ("N mg acetaminophen today") since the product name differs from it.
    if medication.components.count == 1,
       let component = medication.components.first,
       let ingredient = component.ingredient
    {
      let total = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now, calendar: calendar)
      let totalLabel = ingredient.name == medication.displayName
        ? "\(Int(total.rounded())) mg today"
        : "\(Int(total.rounded())) mg \(ingredient.name.lowercased()) today"
      return PRNRowSummary(
        medicationID: medication.id,
        firstLine: medication.displayName,
        secondLine: "\(totalLabel) · \(lastDoseText)",
        highlightedIngredientID: ingredient.id
      )
    }

    // Combo product: surface the ingredient closest to its ceiling.
    var best: (ingredient: Ingredient, percent: Double)?
    for component in medication.components {
      guard let ingredient = component.ingredient, let ceiling = ingredient.dailyCeilingMg, ceiling > 0 else { continue }
      let today = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now, calendar: calendar)
      let percent = today / ceiling
      if percent > (best?.percent ?? -1) { best = (ingredient, percent) }
    }
    // Rounding (vs. truncating) means 99.5% reads as "100% of daily limit"
    // — errs on the side of alerting for a safety-adjacent surface. The raw
    // `percent` (and the underlying mg total) governs every actual safety
    // decision; only the displayed integer rolls.
    let bestSuffix = best.map { " · \($0.ingredient.name.lowercased()) \(Int(($0.percent * 100).rounded()))% of daily limit" } ?? ""
    return PRNRowSummary(
      medicationID: medication.id,
      firstLine: medication.displayName,
      secondLine: "\(lastDoseText)\(bestSuffix)",
      highlightedIngredientID: best?.ingredient.id
    )
  }
}
