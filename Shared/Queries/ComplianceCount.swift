import Foundation
import SwiftData

/// Per-day compliance signal for the History tab footer (SPEC §7.3 of
/// `plans/2026-05-31_PILL_MEALS.md`). Skeleton stub returning zeros — real
/// taken-vs-scheduled math lands in #194.
public enum ComplianceCount {
  public struct Result: Sendable, Equatable {
    public let taken: Int
    public let scheduled: Int

    public init(taken: Int, scheduled: Int) {
      self.taken = taken
      self.scheduled = scheduled
    }
  }

  @MainActor
  public static func compliance(
    for _: Date,
    in _: ModelContext,
    calendar _: Calendar = .current
  ) -> Result {
    Result(taken: 0, scheduled: 0)
  }
}
