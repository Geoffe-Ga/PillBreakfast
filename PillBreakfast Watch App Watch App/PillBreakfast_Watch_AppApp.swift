import SwiftData
import SwiftUI

@main
struct PillBreakfast_Watch_App_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor private var notificationDelegate: NotificationDelegate
  /// Owned for the process lifetime so MetricKit keeps a live subscriber.
  private let crashReporting = CrashReporting()

  init() {
    WatchConnectivityCoordinator.shared.activate()
    crashReporting.start()
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
