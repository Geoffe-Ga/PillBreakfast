import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import SwiftData
import Testing
import WatchConnectivity

@MainActor
struct WatchConnectivityCoordinatorTests {
  @Test func sharedCoordinatorActivatesIdempotently() {
    let coordinator = WatchConnectivityCoordinator.shared
    coordinator.activate()
    coordinator.activate()
    // Double activation must not record an error or leave the state machine wedged.
    #expect(coordinator.lastError == nil)
  }

  @Test func activationStateDisplayNamesAreStable() {
    #expect(WCSessionActivationState.notActivated.displayName == "notActivated")
    #expect(WCSessionActivationState.inactive.displayName == "inactive")
    #expect(WCSessionActivationState.activated.displayName == "activated")
  }

  // MARK: - Inbound regimen ingest (preferences sync)

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func makeStore() throws -> (UserPreferencesStore, () -> Void) {
    let suite = "test.coord.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (UserPreferencesStore(defaults: defaults), { defaults.removePersistentDomain(forName: suite) })
  }

  @Test func ingestingV2SnapshotUpdatesPreferences() throws {
    let (store, cleanup) = try makeStore()
    defer { cleanup() }

    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [],
      preferences: UserPreferences(highRiskHoldDurationSeconds: 1.4)
    )
    let data = try JSONEncoder().encode(snapshot)

    try WatchConnectivityCoordinator.shared.applyRegimen(
      data: data,
      into: makeContext(),
      preferencesStore: store
    )
    #expect(store.preferences.highRiskHoldDurationSeconds == 1.4)
  }

  @Test func ingestingLegacyV1SnapshotDefaultsPreferences() throws {
    let (store, cleanup) = try makeStore()
    defer { cleanup() }
    // Seed a non-default value to prove the v1 ingest resets it to the default.
    store.preferences = UserPreferences(highRiskHoldDurationSeconds: 1.8)

    let data = Data(#"{"schemaVersion":1,"ingredients":[],"medications":[]}"#.utf8)
    try WatchConnectivityCoordinator.shared.applyRegimen(
      data: data,
      into: makeContext(),
      preferencesStore: store
    )
    #expect(store.preferences == UserPreferences())
  }
}
