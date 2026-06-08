import Foundation

/// Pure calendar planning for the watch complication's timeline: the instants
/// where the pending-dose count can change (a dose's ±window opens or closes).
/// Lives in `Shared/` so it's CI-tested without a widget test target.
public enum WidgetTimelinePlan {
  /// Opening (`scheduled − window`) and closing (`scheduled + window`) edges for
  /// every active maintenance dose in `[from, to]`. The caller passes already
  /// non-archived `.maintenance` meds. Result is sorted and de-duplicated.
  ///
  /// Honors `daysOfWeek` (empty = every day), inlines the ISO-weekday conversion
  /// (Gregorian Sunday=1 → ISO 7), and skips DST-invalid wall-clock times.
  public static func transitionDates(
    forMaintenance meds: [Medication],
    from: Date,
    to: Date,
    calendar: Calendar,
    windowMinutes: Int
  ) -> [Date] {
    let window = TimeInterval(windowMinutes * 60)
    var edges: Set<Date> = []
    var day = calendar.startOfDay(for: from)
    let lastDay = calendar.startOfDay(for: to)

    while day <= lastDay {
      let gregorian = calendar.component(.weekday, from: day)
      let isoWeekday = gregorian == 1 ? 7 : gregorian - 1
      for med in meds {
        for dose in med.schedule {
          if !dose.daysOfWeek.isEmpty, !dose.daysOfWeek.contains(isoWeekday) { continue }
          guard let scheduled = calendar.date(
            bySettingHour: dose.hour,
            minute: dose.minute,
            second: 0,
            of: day
          ) else { continue }
          for edge in [scheduled.addingTimeInterval(-window), scheduled.addingTimeInterval(window)]
            where edge >= from && edge <= to
          {
            edges.insert(edge)
          }
        }
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return edges.sorted()
  }
}
