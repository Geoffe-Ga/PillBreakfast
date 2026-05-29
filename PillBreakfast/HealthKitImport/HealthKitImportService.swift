import Foundation

/// iOS-only entry point for importing medications from Apple Health (SPEC §3, §6.1).
///
/// Tracer-skeleton stub. The real flow lands across later EPIC 07 issues —
/// authorization (ISSUE_02), the `HKMedicationDoseEvent` / concept query (ISSUE_03),
/// and mapping into our own SwiftData store (ISSUE_04). HealthKit is a **read-only,
/// import-only** source: PillBreakfast owns its store and never writes back (SPEC §3).
///
/// Deliberately does **not** `import HealthKit` yet: no medication symbols exist on any
/// target until the authorization flow is added, which keeps the watch build provably
/// free of HealthKit Medications symbols (the watch can't use that API at all).
actor HealthKitImportService {
  /// Outcome of an import attempt. Expands as the real flow lands (authorized / denied /
  /// unavailable, then a mapped medication count). For the skeleton there is only the stub.
  enum ImportOutcome: Equatable {
    case comingSoon
  }

  func importMedications() async -> ImportOutcome {
    .comingSoon
  }
}
