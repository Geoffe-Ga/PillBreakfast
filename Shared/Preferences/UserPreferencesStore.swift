import Foundation
import os

/// Observable, App Group `UserDefaults`-backed store for `UserPreferences`.
///
/// On the iPhone this is the authority (Settings writes here, and the value
/// rides out on the next `RegimenSnapshot`). On the watch the WatchConnectivity
/// receive path writes the synced value here so `HighRiskConfirmButton` reads it.
@MainActor
@Observable
public final class UserPreferencesStore {
  public static let shared = UserPreferencesStore()

  /// Persisted on every change. `didSet` won't fire for the load in `init`, which
  /// is what we want — loading shouldn't immediately rewrite the same bytes.
  public var preferences: UserPreferences {
    didSet { persist() }
  }

  @ObservationIgnored private let defaults: UserDefaults
  private static let storageKey = "userPreferences"
  @ObservationIgnored private let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Preferences")

  /// - Parameter defaults: injectable for tests; defaults to the shared App Group
  ///   suite, falling back to `.standard` only if the group is somehow unavailable.
  public init(defaults: UserDefaults? = nil) {
    let resolved = defaults
      ?? UserDefaults(suiteName: PersistenceController.appGroupIdentifier)
      ?? .standard
    self.defaults = resolved

    guard let data = resolved.data(forKey: Self.storageKey) else {
      self.preferences = UserPreferences()
      return
    }
    do {
      self.preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
    } catch {
      // Corrupt/old payload — fall back to defaults rather than trap. Logged so a
      // persistent decode failure is visible instead of silently masked.
      logger.error("Failed to decode stored preferences; using defaults: \(error.localizedDescription, privacy: .public)")
      self.preferences = UserPreferences()
    }
  }

  public func reset() {
    preferences = UserPreferences()
  }

  private func persist() {
    do {
      try defaults.set(JSONEncoder().encode(preferences), forKey: Self.storageKey)
    } catch {
      logger.error("Failed to persist preferences: \(error.localizedDescription, privacy: .public)")
    }
  }
}
