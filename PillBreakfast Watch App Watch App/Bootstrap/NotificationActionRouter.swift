import Foundation
import Observation

/// The dose a snooze action targets, carried from the notification to `SnoozeView`.
public struct SnoozeContext: Identifiable, Sendable, Hashable {
  public let scheduledDoseID: UUID
  public let originalScheduledFor: Date
  public let medicationName: String

  public var id: UUID {
    scheduledDoseID
  }

  public init(scheduledDoseID: UUID, originalScheduledFor: Date, medicationName: String) {
    self.scheduledDoseID = scheduledDoseID
    self.originalScheduledFor = originalScheduledFor
    self.medicationName = medicationName
  }
}

/// Bridges a notification action tap to the SwiftUI view layer. The notification
/// delegate runs off the view hierarchy, so it stashes the snooze context here and
/// the root view observes it to present `SnoozeView`.
@MainActor
@Observable
public final class NotificationActionRouter {
  public static let shared = NotificationActionRouter()

  /// Non-nil while the root view should present `SnoozeView` for this dose.
  public var pendingSnooze: SnoozeContext?

  /// `internal` (not `public`): production uses `.shared`, but tests can spin up a
  /// fresh instance instead of mutating and restoring global state.
  init() {}

  public func presentSnooze(_ context: SnoozeContext) {
    pendingSnooze = context
  }
}
