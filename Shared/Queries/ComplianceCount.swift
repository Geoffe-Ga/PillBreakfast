import Foundation
import SwiftData

/// Per-day compliance signal for the History tab footer (SPEC §7.3 of
/// `plans/2026-05-31_PILL_MEALS.md`). Count-match, no "late" / "missed" framing.
public enum ComplianceCount {
  public struct Result: Sendable, Equatable {
    public let taken: Int
    public let scheduled: Int

    public init(taken: Int, scheduled: Int) {
      self.taken = taken
      self.scheduled = scheduled
    }
  }

  /// `scheduled` = count of `ScheduledDose` rows on non-archived `.maintenance`
  /// meds that apply to `day` (`daysOfWeek` filter respected; empty = every day).
  /// `taken` = count of `.taken` `DoseEvent` rows whose `scheduledFor` lands
  /// inside the day — `nil`-`scheduledFor` events (PRN / anytime logs) are
  /// excluded so the ratio stays honest against the scheduled denominator.
  @MainActor
  public static func compliance(
    for day: Date,
    in context: ModelContext,
    calendar: Calendar = .current
  ) throws -> Result {
    let startOfDay = calendar.startOfDay(for: day)
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      throw ComplianceCountError.calendarArithmeticFailed
    }
    let todayISOWeekday = Self.isoWeekday(fromCalendar: calendar.component(.weekday, from: startOfDay))

    let maintenance = try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .maintenance }

    let scheduled = maintenance.reduce(0) { count, med in
      count + med.schedule.count { dose in
        dose.daysOfWeek.isEmpty || dose.daysOfWeek.contains(todayISOWeekday)
      }
    }

    // `kind` / `status` enum filters and the optional `scheduledFor`
    // comparison all run in memory — `#Predicate` over them is brittle on
    // iOS 26's SwiftData (`unsupportedPredicate` at fetch time). Predicate
    // pins the indexed `takenAt` window.
    let eventsInWindow = try context.fetch(FetchDescriptor<DoseEvent>(
      predicate: #Predicate {
        $0.takenAt >= startOfDay && $0.takenAt < nextDay
      }
    ))
    let taken = eventsInWindow.count { event in
      guard event.status == .taken, let scheduledFor = event.scheduledFor else { return false }
      return scheduledFor >= startOfDay && scheduledFor < nextDay
    }

    return Result(taken: taken, scheduled: scheduled)
  }

  /// SPEC stores ISO weekdays (1 = Mon … 7 = Sun); Calendar uses 1 = Sun … 7 = Sat.
  private static func isoWeekday(fromCalendar calendarWeekday: Int) -> Int {
    calendarWeekday == 1 ? 7 : calendarWeekday - 1
  }
}

public enum ComplianceCountError: Error, Sendable {
  case calendarArithmeticFailed
}
