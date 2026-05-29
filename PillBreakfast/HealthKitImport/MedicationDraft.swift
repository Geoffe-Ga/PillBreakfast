import Foundation

/// Staged value type sitting between the Health query result
/// (`HealthMedicationDraft`) and the persisted `Medication`. The user confirms
/// the ingredient components against this draft on `ConfirmComponentsView`; the
/// save step turns each draft into a real `Medication`.
///
/// `nonisolated` + explicit `Sendable` so the type contract is the schema
/// boundary between the (MainActor) import flow and the (actor-owned)
/// persistence layer — `nonisolated` opts it out of the module's MainActor
/// default so `Sendable` is not the redundant-redundant trigger swiftformat
/// strips for unmarked internal value types.
nonisolated struct MedicationDraft: Hashable, Identifiable {
  let id: UUID
  let displayName: String
  let healthKitConceptID: String

  init(id: UUID = UUID(), displayName: String, healthKitConceptID: String) {
    self.id = id
    self.displayName = displayName
    self.healthKitConceptID = healthKitConceptID
  }
}
