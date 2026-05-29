import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct HealthKitImportTests {
  /// Stands in for the live service so the flow runs without a HealthKit daemon
  /// (which would try to present a system prompt and query the store).
  private struct FakeImporter: HealthKitImporting {
    var auth: Result<HealthKitImportAuthorizationResult, any Error> = .success(.authorized)
    var fetch: Result<[HealthMedicationDraft], any Error> = .success([])

    func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
      try auth.get()
    }

    func fetchUserAnnotatedMedications() async throws -> [HealthMedicationDraft] {
      try fetch.get()
    }
  }

  private struct FakeError: LocalizedError {
    var errorDescription: String? {
      "boom"
    }
  }

  private func draft(_ name: String, scheduled: Bool = false) -> HealthMedicationDraft {
    HealthMedicationDraft(healthKitConceptID: "concept-\(name)", displayName: name, hasSchedule: scheduled)
  }

  // MARK: - Authorization

  @Test func authorizationResultIsExhaustive() {
    // Compile-time guard: adding a case forces an update to `resolve`'s switch.
    for result in [HealthKitImportAuthorizationResult.authorized, .denied, .notAvailable] {
      switch result {
      case .authorized, .denied, .notAvailable: break
      }
    }
  }

  @Test func resolveDeniedShortCircuitsBeforeFetch() async {
    // fetch is wired to throw; a `.denied` result (not `.failed`) proves it was
    // never called after a denied authorization.
    let importer = FakeImporter(auth: .success(.denied), fetch: .failure(FakeError()))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .denied)
  }

  @Test func resolveNotAvailableShortCircuitsBeforeFetch() async {
    let importer = FakeImporter(auth: .success(.notAvailable), fetch: .failure(FakeError()))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .notAvailable)
  }

  @Test func resolveAuthErrorBecomesFailedWithoutBeingSwallowed() async {
    let importer = FakeImporter(auth: .failure(FakeError()))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .failed("boom"))
  }

  // MARK: - Query (0 / 1 / many)

  @Test func resolveLoadsZeroMedications() async {
    let importer = FakeImporter(fetch: .success([]))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .loaded([]))
  }

  @Test func resolveLoadsOneMedication() async {
    let only = draft("Lithium")
    let importer = FakeImporter(fetch: .success([only]))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .loaded([only]))
  }

  @Test func resolveLoadsManyMedications() async {
    let drafts = [draft("Lithium"), draft("Gabapentin", scheduled: true), draft("Vitamin D")]
    let importer = FakeImporter(fetch: .success(drafts))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .loaded(drafts))
  }

  @Test func resolveFetchErrorBecomesFailedWithoutBeingSwallowed() async {
    let importer = FakeImporter(auth: .success(.authorized), fetch: .failure(FakeError()))
    #expect(await HealthKitImportViewState.resolve(using: importer) == .failed("boom"))
  }

  // MARK: - Messages & symbols

  @Test func loadedEmptyExplainsNothingFound() {
    #expect(HealthKitImportViewState.loaded([]).message.contains("No medications"))
    #expect(HealthKitImportViewState.loaded([]).symbolName == "tray")
  }

  @Test func deniedMessageGuidesUserToSettings() {
    #expect(HealthKitImportViewState.denied.message.contains("Settings"))
    #expect(HealthKitImportViewState.denied.symbolName == "heart.slash")
  }

  @Test func notAvailableMessageExplainsHealthIsUnavailable() {
    #expect(HealthKitImportViewState.notAvailable.message.contains("isn't available"))
    #expect(HealthKitImportViewState.notAvailable.symbolName == "heart.slash")
  }

  @Test func failedMessageIncludesTheUnderlyingReason() {
    #expect(HealthKitImportViewState.failed("boom").message.contains("boom"))
  }

  @Test func loadedListUsesTheMedicationSymbol() {
    #expect(HealthKitImportViewState.loaded([draft("Lithium")]).symbolName == "heart.text.square")
    #expect(HealthKitImportViewState.checking.symbolName == "heart.text.square")
  }

  @Test func readOnlyDisclaimerKeepsTheTrustSignal() {
    #expect(HealthKitImportSheet.readOnlyDisclaimer.contains("never writes"))
  }

  // MARK: - Draft identity

  @Test func draftDefaultIDsAreUnique() {
    let a = draft("Lithium")
    let b = draft("Lithium")
    #expect(a.id != b.id)
    #expect(a != b)
  }

  @Test func draftsWithSameIDAreEqual() {
    let id = UUID()
    let a = HealthMedicationDraft(id: id, healthKitConceptID: "c", displayName: "n", hasSchedule: false)
    let b = HealthMedicationDraft(id: id, healthKitConceptID: "c", displayName: "n", hasSchedule: false)
    #expect(a == b)
  }

  // MARK: - Sheet wiring

  @Test func sheetConstructsWithDefaultsAndInjection() {
    _ = HealthKitImportSheet()
    _ = HealthKitImportSheet(importer: FakeImporter(fetch: .success([draft("Lithium")])))
  }

  // MARK: - Selection → MedicationDraft transform (covers the deferred test from #45's review)

  @Test func medicationDraftsCarryOnlyTheSelectedSubset() {
    let a = draft("Lithium")
    let b = draft("Vitamin D")
    let c = draft("Gabapentin", scheduled: true)
    let result = HealthKitImportSheet.medicationDrafts(from: [a, b, c], selectedIDs: [a.id, c.id])
    #expect(result.count == 2)
    #expect(result.map(\.displayName) == ["Lithium", "Gabapentin"])
    #expect(result.map(\.healthKitConceptID) == [a.healthKitConceptID, c.healthKitConceptID])
  }

  @Test func medicationDraftsEmptyWhenNothingSelected() {
    let a = draft("Lithium")
    #expect(HealthKitImportSheet.medicationDrafts(from: [a], selectedIDs: []).isEmpty)
  }
}
