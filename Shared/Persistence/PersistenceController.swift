import Foundation
import os
import SwiftData

/// Shared SwiftData container backed by the App Group store, opened against the PillBreakfast model graph.
@MainActor
public final class PersistenceController {
  public static let shared = PersistenceController()

  public static let appGroupIdentifier = "group.com.creekmasons.pillbreakfast"

  /// The PillBreakfast model graph (SPEC §5.2).
  public static let schema = Schema([
    Ingredient.self,
    MedicationComponent.self,
    Medication.self,
    ScheduledDose.self,
    DoseEvent.self,
  ])

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "Persistence"
  )

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

    // Seed the common-ingredient library on each device's local store. Idempotent,
    // so running it on every launch is fine. A seed failure leaves the library empty
    // (recoverable — the user can still add meds), so we log rather than crash.
    do {
      try IngredientLibrarySeeder.seedIfNeeded(context: container.mainContext)
    } catch {
      Self.logger.error("Ingredient library seeding failed: \(error.localizedDescription, privacy: .public)")
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
