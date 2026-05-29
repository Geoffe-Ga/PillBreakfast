import Foundation

/// Stub iOS-only HealthKit import service; real flow lands in EPIC 07 ISSUE_02–04.
/// Never `import HealthKit` here — keeps the watch build free of HK Medications symbols.
actor HealthKitImportService {
  enum ImportOutcome: Equatable {
    case comingSoon
  }

  func importMedications() async -> ImportOutcome {
    .comingSoon
  }
}
