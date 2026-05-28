import Foundation
import SwiftData

/// Opens the SwiftData `ModelContainer` for PillBreakfast against the App Group
/// container URL shared by the iOS and watchOS targets.
///
/// The schema is intentionally empty in this issue — `@Model` types arrive in
/// the next epic. The controller exists now so both apps can attach
/// `.modelContainer(...)` to their scenes from the very first build, keeping
/// the tracer-code wiring in place end-to-end.
///
/// A missing App Group entitlement is a configuration bug, not a runtime
/// condition. ``appGroupStoreURL()`` traps with `fatalError` so the
/// misconfiguration surfaces at launch instead of silently falling back to a
/// per-process store that the paired target cannot see.
@MainActor
public final class PersistenceController: Sendable {
  /// Process-wide singleton injected into the SwiftUI scene of each target.
  public static let shared = PersistenceController()

  /// App Group identifier locked by the entitlements files on both targets.
  public static let appGroupIdentifier = "group.com.creekmasons.pillbreakfast"

  /// SwiftData container backed by the App Group store URL.
  public let container: ModelContainer

  private init() {
    let url = Self.appGroupStoreURL()
    let configuration = ModelConfiguration(url: url)
    do {
      self.container = try ModelContainer(
        for: Schema([]),
        configurations: configuration
      )
    } catch {
      fatalError("Failed to open SwiftData container at \(url): \(error)")
    }
  }

  /// Returns the App Group container URL where the SwiftData store lives.
  public static func appGroupStoreURL() -> URL {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      fatalError(
        "App Group \"\(appGroupIdentifier)\" is unavailable. Verify entitlements on both targets."
      )
    }
    return containerURL.appendingPathComponent("PillBreakfast.store")
  }
}
