import Foundation
import SwiftData

/// A dose the watch should prompt for right now: a scheduled dose within the
/// active window that hasn't been logged yet today.
public struct PendingDose: Sendable, Hashable {
  public let medicationID: UUID
  public let scheduledFor: Date
  public let quantity: Int

  public init(medicationID: UUID, scheduledFor: Date, quantity: Int) {
    self.medicationID = medicationID
    self.scheduledFor = scheduledFor
    self.quantity = quantity
  }
}

public enum PendingQueueSelector {
  /// Returns the doses due around `now` that have not yet been logged today.
  ///
  /// Skeleton: always returns `[]`, so the watch renders "All caught up". The
  /// real window/dedup logic (scheduled within ±60 min, no matching DoseEvent
  /// today, medication not archived) lands in EPIC_03_ISSUE_06.
  @MainActor
  public static func pendingDoses(at now: Date, in context: ModelContext) throws -> [PendingDose] {
    _ = now
    _ = context
    return []
  }
}
