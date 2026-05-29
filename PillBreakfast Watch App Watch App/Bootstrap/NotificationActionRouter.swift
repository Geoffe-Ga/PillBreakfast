import Observation
import UserNotifications

/// Bridges a notification action tap to the SwiftUI view layer. The notification
/// delegate runs off the view hierarchy, so it sets a flag here and the root view
/// observes it to present the right screen. Today only the Snooze action routes
/// (to `SnoozeView`); the reschedule logic itself is EPIC_06_ISSUE_02.
@MainActor
@Observable
public final class NotificationActionRouter {
  public static let shared = NotificationActionRouter()

  /// When true, the root view presents `SnoozeView`.
  public var isShowingSnooze = false

  /// `internal` (not `public`): production uses `.shared`, but tests can spin up a
  /// fresh instance instead of mutating and restoring global state.
  init() {}

  /// Maps a delivered action identifier onto a routing flag.
  public func handle(actionIdentifier: String) {
    if actionIdentifier == NotificationCategory.Action.snooze {
      isShowingSnooze = true
    }
  }
}
