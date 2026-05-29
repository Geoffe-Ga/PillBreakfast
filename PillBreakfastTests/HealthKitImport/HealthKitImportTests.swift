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

  @Test func authorizationResultHasThreeCases() {
    let all: [HealthKitImportAuthorizationResult] = [.authorized, .denied, .notAvailable]
    #expect(all.count == 3)
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

  @Test func deniedMessageGuidesUserToSettings() {
    #expect(HealthKitImportViewState.denied.message.contains("Settings"))
  }

  @Test func failedMessageIncludesTheUnderlyingReason() {
    #expect(HealthKitImportViewState.failed("boom").message.contains("boom"))
  }

  @Test func sheetConstructsWithDefaultAndInjectedImporter() {
    _ = HealthKitImportSheet()
    _ = HealthKitImportSheet(importer: FakeImporter(outcome: .success(.notAvailable)))
  }
}
