import Foundation
import SwiftData

/// Shared SwiftData container backed by the App Group store, opened against the PillBreakfast model graph.
@MainActor
public final class PersistenceController {
  public static let shared = PersistenceController()

  public static let appGroupIdentifier = "group.com.creekmasons.pillbreakfast"

  /// The PillBreakfast model graph. Field bodies and relationships land in EPIC 02; these are id-only shells.
  public static let schema = Schema([
    Ingredient.self,
    MedicationComponent.self,
    Medication.self,
    ScheduledDose.self,
    DoseEvent.self,
  ])

  public let container: ModelContainer

  private init() {
    let url = Self.appGroupStoreURL
    let configuration = ModelConfiguration(url: url)
    do {
      self.container = try ModelContainer(
        for: Self.schema,
        configurations: configuration
      )
    } catch {
      fatalError("Failed to open SwiftData container at \(url): \(error)")
    }
  }

  public static var appGroupStoreURL: URL {
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
