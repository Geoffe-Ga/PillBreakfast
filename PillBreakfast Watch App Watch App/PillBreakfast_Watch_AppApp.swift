import SwiftData
import SwiftUI

@main
struct PillBreakfast_Watch_App_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor private var notificationDelegate: NotificationDelegate

  init() {
    WatchConnectivityCoordinator.shared.activate()
  }

  var body: some Scene {
    WindowGroup {
      RightNowView()
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
