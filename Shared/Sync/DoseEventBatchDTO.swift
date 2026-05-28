import Foundation

/// Value-type mirror of a `DoseEvent` for the reverse (watch → iPhone) channel.
/// The medication is referenced by `medicationID` — it already exists on the
/// iPhone via the regimen snapshot, so we never re-send the `Medication`.
public struct DoseEventDTO: Codable, Sendable, Hashable {
  public let id: UUID
  public let medicationID: UUID
  public let scheduledFor: Date?
  public let takenAt: Date
  public let quantity: Int
  public let status: DoseStatus
  public let loggedOn: LogSource
  public let notes: String?
  public let ingredientAmounts: [LoggedIngredientAmount]

  public init(
    id: UUID,
    medicationID: UUID,
    scheduledFor: Date?,
    takenAt: Date,
    quantity: Int,
    status: DoseStatus,
    loggedOn: LogSource,
    notes: String?,
    ingredientAmounts: [LoggedIngredientAmount]
  ) {
    self.id = id
    self.medicationID = medicationID
    self.scheduledFor = scheduledFor
    self.takenAt = takenAt
    self.quantity = quantity
    self.status = status
    self.loggedOn = loggedOn
    self.notes = notes
    self.ingredientAmounts = ingredientAmounts
  }
}

public struct DoseEventBatch: Codable, Sendable, Hashable {
  public var events: [DoseEventDTO]

  public init(events: [DoseEventDTO]) {
    self.events = events
  }
}
