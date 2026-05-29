import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct UserPreferencesStoreTests {
  @Test func persistsAcrossInstances() throws {
    let suite = "test.prefs.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UserPreferencesStore(defaults: defaults)
    store.preferences = UserPreferences(highRiskHoldDurationSeconds: 1.2)

    // A fresh instance reading the same suite must see the persisted value.
    let reloaded = UserPreferencesStore(defaults: defaults)
    #expect(reloaded.preferences.highRiskHoldDurationSeconds == 1.2)
  }

  @Test func defaultsWhenSuiteEmpty() throws {
    let suite = "test.prefs.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UserPreferencesStore(defaults: defaults)
    #expect(store.preferences == UserPreferences())
  }

  @Test func resetRestoresDefaultAndPersists() throws {
    let suite = "test.prefs.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = UserPreferencesStore(defaults: defaults)
    store.preferences = UserPreferences(highRiskHoldDurationSeconds: 1.5)
    store.reset()
    #expect(store.preferences.highRiskHoldDurationSeconds == UserPreferences.defaultHoldDuration)

    let reloaded = UserPreferencesStore(defaults: defaults)
    #expect(reloaded.preferences == UserPreferences())
  }
}
