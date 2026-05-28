import Foundation
import SwiftData

/// Writes `DoseEvent`s to the local store. The `ingredientAmounts` snapshot is
/// built from the medication's components **at log time** and never recomputed,
/// so later edits to the product can't rewrite history (SPEC §5.3, CLAUDE.md).
@MainActor
public enum DoseEventWriter {
  @discardableResult
  public static func writeDoseEvent(
    for medication: Medication,
    scheduledFor: Date?,
    quantity: Int,
    status: DoseStatus,
    loggedOn: LogSource,
    at now: Date,
    in context: ModelContext
  ) throws -> DoseEvent {
    let amounts: [LoggedIngredientAmount] = medication.components.compactMap { component in
      guard let ingredient = component.ingredient else { return nil }
      return LoggedIngredientAmount(
        ingredientID: ingredient.id,
        ingredientName: ingredient.name,
        totalMg: Double(quantity) * component.dosagePerUnitMg
      )
    }

    let event = DoseEvent(
      id: UUID(),
      medication: medication,
      scheduledFor: scheduledFor,
      takenAt: now,
      quantity: quantity,
      status: status,
      loggedOn: loggedOn, // callers pass .watch — the wrist is the only logging surface (SPEC §6)
      ingredientAmounts: amounts
    )
    context.insert(event)
    try context.save()
    return event
  }
}
