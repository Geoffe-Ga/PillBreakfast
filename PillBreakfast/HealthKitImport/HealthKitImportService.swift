import Foundation
import HealthKit

/// Outcome of asking the user for per-medication read access (SPEC §3.1).
/// `notAvailable` covers devices without Health (e.g. iPad / some simulators).
enum HealthKitImportAuthorizationResult {
  case authorized
  case denied
  case notAvailable
}

/// The slice of the HealthKit authorization flow the import sheet depends on,
/// abstracted so the sheet can be exercised with a fake. The real service talks
/// to the HealthKit daemon and would try to present a system prompt, so tests
/// must never touch it.
protocol HealthKitImporting: Sendable {
  func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult
}

/// iOS-only HealthKit import service. It lives in the `PillBreakfast` app target
/// only, never `Shared/`, so the watch never compiles HK Medications symbols —
/// which are iOS/iPadOS/visionOS-only regardless (SPEC §3.2). PillBreakfast only
/// ever *reads* from Health; it cannot write (SPEC §3.2, confirmed by Apple DTS).
actor HealthKitImportService: HealthKitImporting {
  private let store = HKHealthStore()

  init() {}

  /// Requests *per-medication* read scope: HealthKit presents a picker and the
  /// user chooses which Health medications PillBreakfast may see (SPEC §3.1). We
  /// never request blanket read.
  ///
  /// Reading this "deliberately confusing" API critically (SPEC §11 Phase 6):
  /// `requestPerObjectReadAuthorization` reports only whether the *prompt*
  /// finished — its success "does NOT indicate whether the application was
  /// granted authorization" (HKHealthStore.h). And for read scopes,
  /// `authorizationStatus(for:)` deliberately stays `.notDetermined` so apps
  /// cannot infer whether the user even has medication data. So at the
  /// authorization step alone we can only tell these three outcomes apart;
  /// *which* medications were actually shared is knowable only by querying, which
  /// lands in the next issue (EPIC 07 ISSUE 03).
  ///
  /// A user-cancelled prompt arrives as `HKError.errorUserCanceled` and maps to
  /// `.denied` (the sheet then guides them back via Settings). Any other error
  /// is genuine and propagates — it is not swallowed.
  func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
    guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
    do {
      try await store.requestPerObjectReadAuthorization(
        for: HKObjectType.userAnnotatedMedicationType(),
        predicate: nil
      )
      return .authorized
    } catch let error as HKError where error.code == .errorUserCanceled {
      return .denied
    }
  }
}
