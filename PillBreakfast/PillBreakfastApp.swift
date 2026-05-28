import SwiftData
import SwiftUI

@main
struct PillBreakfastApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
