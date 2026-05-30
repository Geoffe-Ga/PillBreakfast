import os
import SwiftData
import SwiftUI

@main
struct PillBreakfastApp: App {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Bootstrap")
  /// Owned for the process lifetime so MetricKit keeps a live subscriber.
  private let crashReporting = CrashReporting()

  init() {
    WatchConnectivityCoordinator.shared.activate()
    crashReporting.start()
    // iPhone-only stub seed so the EPIC 02 sync gate has a medication to push.
    do {
      try StubMedicationSeeder.seedIfNeeded(context: PersistenceController.shared.container.mainContext)
    } catch {
      Self.logger.error("Stub medication seeding failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
        .environment(UserPreferencesStore.shared)
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
