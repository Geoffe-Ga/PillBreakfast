import os
import SwiftData
import SwiftUI

@main
struct PillBreakfast_Watch_App_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor private var notificationDelegate: NotificationDelegate
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "DeepLink")

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
        .onOpenURL { Self.handleDeepLink($0) }
    }
    .modelContainer(PersistenceController.shared.container)
  }

  /// Routes the complication's `pillbreakfast://tap-through` link. Opening the URL
  /// already foregrounds the app onto `RightNowView` (which shows the queue when
  /// doses are pending), so this just validates the link and logs.
  private static func handleDeepLink(_ url: URL) {
    guard url.scheme == "pillbreakfast", url.host == "tap-through" else {
      logger.warning("Ignoring unrecognized deep link: \(url.absoluteString, privacy: .public)")
      return
    }
    logger.info("Opened from complication deep link.")
  }
}
