import SwiftData
import SwiftUI

@main
struct PillBreakfast_Watch_App_Watch_AppApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
