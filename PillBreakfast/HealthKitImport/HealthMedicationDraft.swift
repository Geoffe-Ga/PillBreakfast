import Foundation

/// A value-type snapshot of a Health medication, carrying only the fields
/// PillBreakfast needs for the import-selection list. The live
/// `HKUserAnnotatedMedication` never escapes the service.
///
/// `nonisolated` so it opts out of the module's default `@MainActor` isolation:
/// the service builds these on its own actor (off the main actor) and returns
/// them across the boundary, which requires the type to be a plain, implicitly
/// `Sendable` value type rather than main-actor-isolated.
///
/// Note on `hasSchedule` (not scheduled times): iOS 26's HealthKit exposes only
/// *whether* a medication has a schedule (`HKUserAnnotatedMedication.hasSchedule`)
/// — the actual dose times are not available to third-party apps. So the import
/// list can show "Scheduled" vs "As needed" but cannot pre-fill reminder times;
/// the user sets those in PillBreakfast after import.
nonisolated struct HealthMedicationDraft: Hashable, Identifiable {
  /// PillBreakfast-side row identity (selection key). Distinct from the Health
  /// concept token below, which is the cross-device medication identity.
  let id: UUID
  /// Stable token for the Health medication concept, persisted onto
  /// `Medication.healthKitConceptID` at mapping time (EPIC 07 ISSUE 04).
  let healthKitConceptID: String
  let displayName: String
  let hasSchedule: Bool

  init(id: UUID = UUID(), healthKitConceptID: String, displayName: String, hasSchedule: Bool) {
    self.id = id
    self.healthKitConceptID = healthKitConceptID
    self.displayName = displayName
    self.hasSchedule = hasSchedule
  }
}
