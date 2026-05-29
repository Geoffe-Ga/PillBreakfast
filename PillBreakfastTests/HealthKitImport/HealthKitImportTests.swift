import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct HealthKitImportTests {
  /// Stands in for the live service so the sheet's flow runs without a HealthKit
  /// daemon (which would try to present a system prompt).
  private struct FakeImporter: HealthKitImporting {
    let outcome: Result<HealthKitImportAuthorizationResult, any Error>

    func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
      try outcome.get()
    }
  }

  private struct FakeError: LocalizedError {
    var errorDescription: String? {
      "boom"
    }
  }

  @Test func authorizationResultIsExhaustive() {
    // Compile-time guard: adding a case without updating the mapping in
    // `HealthKitImportViewState.mapped(from:)` becomes a build error.
    for result in [HealthKitImportAuthorizationResult.authorized, .denied, .notAvailable] {
      switch result {
      case .authorized, .denied, .notAvailable: break
      }
    }
  }

  @Test func eachResultMapsToItsViewState() {
    #expect(HealthKitImportViewState.mapped(from: .authorized) == .authorized)
    #expect(HealthKitImportViewState.mapped(from: .denied) == .denied)
    #expect(HealthKitImportViewState.mapped(from: .notAvailable) == .notAvailable)
  }

  @Test func fakeImporterDrivesAuthorizedState() async {
    let importer = FakeImporter(outcome: .success(.authorized))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .authorized)
  }

  @Test func fakeImporterDrivesDeniedState() async {
    let importer = FakeImporter(outcome: .success(.denied))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .denied)
  }

  @Test func fakeImporterDrivesNotAvailableState() async {
    let importer = FakeImporter(outcome: .success(.notAvailable))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .notAvailable)
  }

  @Test func thrownErrorBecomesFailedStateWithoutBeingSwallowed() async {
    let importer = FakeImporter(outcome: .failure(FakeError()))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .failed("boom"))
  }

  @Test func checkingStateHasMessageAndSymbol() {
    #expect(!HealthKitImportViewState.checking.message.isEmpty)
    #expect(HealthKitImportViewState.checking.symbolName == "heart.text.square")
  }

  @Test func authorizedMessageKeepsTheReadOnlyTrustSignal() {
    let message = HealthKitImportViewState.authorized.message
    #expect(message.contains("never writes"))
    #expect(HealthKitImportViewState.authorized.symbolName == "heart.text.square")
  }

  @Test func notAvailableMessageExplainsHealthIsUnavailable() {
    #expect(HealthKitImportViewState.notAvailable.message.contains("isn't available"))
    #expect(HealthKitImportViewState.notAvailable.symbolName == "heart.slash")
  }

  @Test func deniedMessageGuidesUserToSettings() {
    #expect(HealthKitImportViewState.denied.message.contains("Settings"))
    #expect(HealthKitImportViewState.denied.symbolName == "heart.slash")
  }

  @Test func failedMessageIncludesTheUnderlyingReason() {
    #expect(HealthKitImportViewState.failed("boom").message.contains("boom"))
  }

  @Test func sheetConstructsWithDefaultAndInjectedImporter() {
    _ = HealthKitImportSheet()
    _ = HealthKitImportSheet(importer: FakeImporter(outcome: .success(.notAvailable)))
  }
}
