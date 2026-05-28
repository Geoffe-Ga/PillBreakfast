import Foundation
import SwiftData

@Model
public final class DoseEvent {
  // PRN running totals fetch recent events by date on every watch app open,
  // so takenAt is indexed to keep that query off a full-table scan.
  #Index<DoseEvent>([\.takenAt])

  @Attribute(.unique) public var id: UUID
  public var medication: Medication?
  public var scheduledFor: Date? // nil for PRN
  public var takenAt: Date
  public var quantity: Int // pills taken
  public var status: DoseStatus // .taken | .skipped | .snoozed
  public var loggedOn: LogSource // .watch | .iphone
  public var notes: String?

  /// Denormalized snapshot of what was actually consumed, per ingredient.
  /// Stored at log time so that editing a Medication's components later
  /// does not retroactively rewrite history.
  public var ingredientAmounts: [LoggedIngredientAmount]

  public init(
    id: UUID = UUID(),
    medication: Medication? = nil,
    scheduledFor: Date? = nil,
    takenAt: Date,
    quantity: Int,
    status: DoseStatus,
    loggedOn: LogSource,
    notes: String? = nil,
    ingredientAmounts: [LoggedIngredientAmount] = []
  ) {
    self.id = id
    self.medication = medication
    self.scheduledFor = scheduledFor
    self.takenAt = takenAt
    self.quantity = quantity
    self.status = status
    self.loggedOn = loggedOn
    self.notes = notes
    self.ingredientAmounts = ingredientAmounts
  }
}
