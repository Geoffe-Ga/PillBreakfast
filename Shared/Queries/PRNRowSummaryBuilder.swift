import Foundation
import SwiftData

/// One PRN product's row content for the watch PRN list. Two lines: the product
/// name, and a today-total / last-dose summary whose shape depends on the product
/// variant (SPEC §7.3).
public struct PRNRowSummary: Sendable, Hashable, Identifiable {
  public let medicationID: UUID
  public let displayName: String
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
    displayName: String,
    firstLine: String,
    secondLine: String,
    highlightedIngredientID: UUID?
  ) {
    self.medicationID = medicationID
    self.displayName = displayName
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
        ? "\(Int(total)) mg today"
        : "\(Int(total)) mg \(ingredient.name.lowercased()) today"
      return PRNRowSummary(
        medicationID: medication.id,
        displayName: medication.displayName,
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
    let bestSuffix = best.map { " · \($0.ingredient.name.lowercased()) \(Int($0.percent * 100))% of daily limit" } ?? ""
    return PRNRowSummary(
      medicationID: medication.id,
      displayName: medication.displayName,
      firstLine: medication.displayName,
      secondLine: "\(lastDoseText)\(bestSuffix)",
      highlightedIngredientID: best?.ingredient.id
    )
  }
}
