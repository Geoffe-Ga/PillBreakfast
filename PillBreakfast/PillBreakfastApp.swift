import os
import SwiftData
import SwiftUI

@main
struct PillBreakfastApp: App {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Bootstrap")

  init() {
    WatchConnectivityCoordinator.shared.activate()
    // `_ = ` to force the lazy `static let` initializer, which registers the
    // MetricKit subscriber exactly once even if SwiftUI reconstructs the
    // App struct on a scene-lifecycle event.
    _ = CrashReporting.shared
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
