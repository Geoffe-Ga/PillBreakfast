import Foundation
import SwiftData

/// Skips a snoozed occurrence: logs a `.skipped` `DoseEvent` for it and clears its
/// snooze count. Extracted from the warning view so the combined flow is testable.
@MainActor
public enum SnoozeSkip {
  public enum SkipError: Error, Equatable {
    /// The scheduled dose (or its medication) couldn't be resolved from the id.
    case doseNotFound
  }

  public static func skip(
    scheduledDoseID: UUID,
    originalScheduledFor: Date,
    at now: Date = .now,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws {
    let id = scheduledDoseID
    guard
      let dose = try context.fetch(FetchDescriptor<ScheduledDose>(predicate: #Predicate { $0.id == id })).first,
      let medication = dose.medication
    else {
      throw SkipError.doseNotFound
    }

    try DoseEventWriter.writeDoseEvent(
      for: medication,
      scheduledFor: originalScheduledFor,
      quantity: dose.quantity,
      status: .skipped,
      loggedOn: .watch,
      at: now,
      in: context
    )
    // Reset on the dose's scheduled day — the same key `increment` wrote under — so a
    // skip the next morning still clears a count snoozed late the night before.
    try SnoozeRecordStore.reset(
      scheduledDoseID: scheduledDoseID,
      on: originalScheduledFor,
      in: context,
      calendar: calendar
    )
  }
}
