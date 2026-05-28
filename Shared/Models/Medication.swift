import Foundation
import SwiftData

@Model
public final class Medication {
  // Regimen loads filter out archived meds on every fetch, so isArchived is
  // indexed to avoid scanning archived rows.
  #Index<Medication>([\.isArchived])

  @Attribute(.unique) public var id: UUID
  public var displayName: String // "Tylenol Extra Strength"
  public var fullName: String? // "Acetaminophen 500mg"
  public var unitForm: MedicationForm // .tablet | .capsule | .liquid | .other
  public var kind: MedicationKind // .maintenance | .prn
  public var colorHex: String? // "#RRGGBB" format; validated by the SwiftUI color layer, not here
  public var notes: String?
  public var isArchived: Bool
  public var createdAt: Date

  /// Optional Health link, populated only if imported
  public var healthKitConceptID: String?

  /// PRN UX config (per-product, not per-ingredient). Only meaningful when `kind == .prn`.
  public var prnAvailableQuantities: [Int] // [1, 2] for Tylenol Extra Strength

  @Relationship(deleteRule: .cascade, inverse: \MedicationComponent.medication)
  public var components: [MedicationComponent] // 1 for simple meds, 2-4 for combos

  @Relationship(deleteRule: .cascade, inverse: \ScheduledDose.medication)
  public var schedule: [ScheduledDose]

  @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medication)
  public var doseEvents: [DoseEvent]

  // Computed: a product is high-risk if any of its ingredients is.
  public var isHighRisk: Bool {
    components.contains { $0.ingredient?.isHighRisk == true }
  }

  public init(
    id: UUID = UUID(),
    displayName: String,
    fullName: String? = nil,
    unitForm: MedicationForm,
    kind: MedicationKind,
    colorHex: String? = nil,
    notes: String? = nil,
    isArchived: Bool = false,
    createdAt: Date = .now,
    healthKitConceptID: String? = nil,
    prnAvailableQuantities: [Int] = [],
    components: [MedicationComponent] = [],
    schedule: [ScheduledDose] = [],
    doseEvents: [DoseEvent] = []
  ) {
    self.id = id
    self.displayName = displayName
    self.fullName = fullName
    self.unitForm = unitForm
    self.kind = kind
    self.colorHex = colorHex
    self.notes = notes
    self.isArchived = isArchived
    self.createdAt = createdAt
    self.healthKitConceptID = healthKitConceptID
    self.prnAvailableQuantities = prnAvailableQuantities
    self.components = components
    self.schedule = schedule
    self.doseEvents = doseEvents
  }
}
