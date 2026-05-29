import Foundation
import HealthKit
import Synchronization

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
  func fetchUserAnnotatedMedications() async throws -> [HealthMedicationDraft]
}

/// iOS-only HealthKit import service. It lives in the `PillBreakfast` app target
/// only, never `Shared/`, so the watch never compiles HK Medications symbols —
/// which are iOS/iPadOS/visionOS-only regardless (SPEC §3.2). PillBreakfast only
/// ever *reads* from Health; it cannot write (SPEC §3.2, confirmed by Apple DTS).
actor HealthKitImportService: HealthKitImporting {
  private let store = HKHealthStore()

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

  /// One-shot fetch of the user's (non-archived) Health medications, mapped to
  /// `Sendable` drafts. Incremental anchored delta-sync is deliberately deferred
  /// to future work (the v1 import is a single snapshot).
  ///
  /// `HKUserAnnotatedMedicationQuery` is a completion-style enumeration query: its
  /// handler fires once per medication and a final time with `done == true`. We
  /// accumulate under a `Mutex` (the handler runs on an arbitrary HealthKit queue,
  /// so the shared buffer must be synchronized for Swift 6) and resume the
  /// continuation exactly once — the `finished` latch guards against the double
  /// resume that would trap if HealthKit delivered an error followed by `done`.
  func fetchUserAnnotatedMedications() async throws -> [HealthMedicationDraft] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    let medications: [HKUserAnnotatedMedication] = try await withCheckedThrowingContinuation { continuation in
      let state = Mutex<(items: [HKUserAnnotatedMedication], finished: Bool)>(([], false))
      let query = HKUserAnnotatedMedicationQuery(predicate: nil, limit: HKObjectQueryNoLimit) { _, medication, done, error in
        let outcome: Result<[HKUserAnnotatedMedication], any Error>? = state.withLock { state in
          guard !state.finished else { return nil }
          if let error {
            state.finished = true
            return .failure(error)
          }
          if let medication {
            state.items.append(medication)
          }
          guard done else { return nil }
          state.finished = true
          return .success(state.items)
        }
        switch outcome {
        case let .success(items): continuation.resume(returning: items)
        case let .failure(error): continuation.resume(throwing: error)
        case nil: break
        }
      }
      store.execute(query)
    }
    return try medications
      .filter { !$0.isArchived }
      .map(Self.draft(from:))
  }

  private nonisolated static func draft(from medication: HKUserAnnotatedMedication) throws -> HealthMedicationDraft {
    let concept = medication.medication
    // `HKHealthConceptIdentifier` exposes no public string, but it is
    // `NSSecureCoding` and documented stable across devices, so its archived
    // bytes form a stable, comparable token for `Medication.healthKitConceptID`.
    let identifierData = try NSKeyedArchiver.archivedData(
      withRootObject: concept.identifier,
      requiringSecureCoding: true
    )
    return HealthMedicationDraft(
      healthKitConceptID: identifierData.base64EncodedString(),
      displayName: medication.nickname ?? concept.displayText,
      hasSchedule: medication.hasSchedule
    )
  }
}
