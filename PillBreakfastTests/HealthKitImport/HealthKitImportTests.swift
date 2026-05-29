import Foundation
@testable import PillBreakfast
import SwiftData
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

  // MARK: - Idempotent re-import (EPIC 07 ISSUE 05 / SPEC §10 Phase 6 gate)

  @Test func medicationDraftsSkipsAlreadyImportedConceptTokens() {
    let a = draft("Lithium") // conceptID == "concept-Lithium"
    let b = draft("Vitamin D") // conceptID == "concept-Vitamin D"
    let result = HealthKitImportSheet.medicationDrafts(
      from: [a, b],
      selectedIDs: [a.id, b.id],
      existingConceptIDs: [a.healthKitConceptID]
    )
    // Lithium is already imported and is dropped even though it's selected;
    // Vitamin D remains. This is the defense-in-depth filter — the row would
    // also be UI-disabled, but the mapper enforces the contract regardless.
    #expect(result.count == 1)
    #expect(result.first?.displayName == "Vitamin D")
  }

  @Test func medicationDraftsEmptyWhenEveryDraftIsAlreadyImported() {
    let a = draft("Lithium")
    let b = draft("Vitamin D")
    let result = HealthKitImportSheet.medicationDrafts(
      from: [a, b],
      selectedIDs: [a.id, b.id],
      existingConceptIDs: [a.healthKitConceptID, b.healthKitConceptID]
    )
    #expect(result.isEmpty)
  }

  @Test func fetchExistingConceptIDsReturnsLinkedTokensOnly() throws {
    let context = try makeInMemoryContext()
    // Manually-added medications (no Health link) must not appear in the
    // dedupe set, otherwise a user-created med name colliding with a future
    // Health med would block import.
    let manual = Medication(displayName: "Manual", unitForm: .tablet, kind: .maintenance)
    let imported = Medication(
      displayName: "Lithium",
      unitForm: .tablet,
      kind: .maintenance,
      healthKitConceptID: "lithium-token"
    )
    context.insert(manual)
    context.insert(imported)
    try context.save()

    let ids = HealthKitImportSheet.fetchExistingConceptIDs(from: context)
    #expect(ids == ["lithium-token"])
  }

  @Test func fetchExistingConceptIDsReturnsEmptyOnFreshStore() throws {
    let context = try makeInMemoryContext()
    #expect(HealthKitImportSheet.fetchExistingConceptIDs(from: context).isEmpty)
  }

  /// Phase 6 gate: setting up Lithium in Health, running the import, then
  /// running it again must not produce a second `Medication`. Verifies the
  /// full projection path — `fetchExistingConceptIDs` →
  /// `medicationDrafts(...existingConceptIDs:)` — against a real SwiftData
  /// store, mirroring what the sheet does at task time.
  @Test func reImportInsertsZeroNewMedications() throws {
    let context = try makeInMemoryContext()
    let lithium = draft("Lithium", scheduled: true) // conceptID "concept-Lithium"

    // First import: nothing exists yet, so the mapper hands us one draft.
    let firstProjection = HealthKitImportSheet.medicationDrafts(
      from: [lithium],
      selectedIDs: [lithium.id],
      existingConceptIDs: HealthKitImportSheet.fetchExistingConceptIDs(from: context)
    )
    #expect(firstProjection.count == 1)
    insertMedications(from: firstProjection, into: context)
    try context.save()
    #expect(try context.fetch(FetchDescriptor<Medication>()).count == 1)

    // Re-import (same Health-side draft, same conceptID): the existing-set is
    // now populated, the mapper drops the draft, and the store stays at one.
    let existing = HealthKitImportSheet.fetchExistingConceptIDs(from: context)
    #expect(existing == [lithium.healthKitConceptID])
    let secondProjection = HealthKitImportSheet.medicationDrafts(
      from: [lithium],
      selectedIDs: [lithium.id],
      existingConceptIDs: existing
    )
    #expect(secondProjection.isEmpty)
    insertMedications(from: secondProjection, into: context)
    try context.save()
    #expect(try context.fetch(FetchDescriptor<Medication>()).count == 1)
  }

  // MARK: - Fixtures

  private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  /// Mirrors the `Medication` shape `ConfirmComponentsView.performImport`
  /// persists — minus the user-confirmed components, which are immaterial to
  /// dedupe (the dedupe key is `healthKitConceptID`, set at construction).
  private func insertMedications(from drafts: [MedicationDraft], into context: ModelContext) {
    for draft in drafts {
      context.insert(Medication(
        displayName: draft.displayName,
        unitForm: .tablet,
        kind: .maintenance,
        healthKitConceptID: draft.healthKitConceptID
      ))
    }
  }
}
