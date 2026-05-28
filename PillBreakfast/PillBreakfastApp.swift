import SwiftData
import SwiftUI

@main
struct PillBreakfastApp: App {
  init() {
    WatchConnectivityCoordinator.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
