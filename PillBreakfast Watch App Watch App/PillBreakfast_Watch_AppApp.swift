import SwiftData
import SwiftUI

@main
struct PillBreakfast_Watch_App_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor private var notificationDelegate: NotificationDelegate

  init() {
    WatchConnectivityCoordinator.shared.activate()
    // See `CrashReporting.shared` for the single-registration rationale.
    _ = CrashReporting.shared
  }

  var body: some Scene {
    WindowGroup {
      RightNowView()
        .environment(UserPreferencesStore.shared)
        .environment(NotificationActionRouter.shared)
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
