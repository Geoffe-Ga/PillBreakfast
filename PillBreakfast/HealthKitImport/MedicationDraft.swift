import Foundation

/// Staged value type sitting between the Health query result
/// (`HealthMedicationDraft`) and the persisted `Medication`. The user confirms
/// the ingredient components against this draft on `ConfirmComponentsView`; the
/// save step turns each draft into a real `Medication`.
struct MedicationDraft: Hashable, Identifiable {
  let id: UUID
  let displayName: String
  let healthKitConceptID: String

  init(id: UUID = UUID(), displayName: String, healthKitConceptID: String) {
    self.id = id
    self.displayName = displayName
    self.healthKitConceptID = healthKitConceptID
  }
}
