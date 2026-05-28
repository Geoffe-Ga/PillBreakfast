import Foundation
import os
import SwiftData

/// Writes `DoseEvent`s to the local store. The `ingredientAmounts` snapshot is
/// built from the medication's components **at log time** and never recomputed,
/// so later edits to the product can't rewrite history.
@MainActor
public enum DoseEventWriter {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "DoseLogging")

  /// - Parameter loggedOn: which surface recorded the dose; callers pass `.watch`
  ///   since the wrist is the only logging surface.
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
      guard let ingredient = component.ingredient else {
        // Store-integrity violation: we can't snapshot an ingredient we don't know.
        // Log loudly and omit — better to undercount than to attribute mg to nil.
        logger.warning("Component \(component.id, privacy: .public) has no ingredient; omitted from dose snapshot.")
        return nil
      }
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
      loggedOn: loggedOn,
      ingredientAmounts: amounts
    )
    context.insert(event)
    try context.save()
    return event
  }
}
