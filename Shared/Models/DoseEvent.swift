import Foundation
import SwiftData

@Model
public final class DoseEvent {
  // PRN running totals fetch recent events by date on every watch app open,
  // so takenAt is indexed to keep that query off a full-table scan.
  #Index<DoseEvent>([\.takenAt])

  /// Sentinel `medicationID` for rows that predate the denormalized field.
  /// Lightweight migration seats this on existing rows (a non-optional new
  /// attribute needs a default); `DoseEventMigrator.backfillMedicationIDs`
  /// then replaces it from the live `medication` relationship at first launch.
  /// The all-zero UUID never collides with a real medication id (`UUID()`).
  public static let unlinkedMedicationID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

  @Attribute(.unique) public var id: UUID
  public var medication: Medication?

  /// Denormalized medication id, stamped at log time. Lets the per-event
  /// "which medication?" lookup (hot path: `PendingQueueSelector.loggedSlotKeys`)
  /// skip the `medication?` relationship fault — the cascade-fetch hazard SPEC
  /// §5.2 calls out, the same reason `ingredientAmounts` is denormalized. The
  /// live `medication` relationship stays for cascade-delete; this field is never
  /// recomputed from it, so deleting a Medication doesn't rewrite history.
  public var medicationID: UUID = DoseEvent.unlinkedMedicationID

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
    medicationID: UUID,
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
