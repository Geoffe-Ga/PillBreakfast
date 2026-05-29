/// Decides whether the snooze flow shows the time picker or the
/// fourth-consecutive-snooze warning (SPEC §8.3: warn on the fourth — i.e. once
/// the occurrence has already been snoozed three times).
enum SnoozeRoute: Equatable {
  case picker
  case warning
}

enum SnoozeViewRouter {
  /// Once an occurrence has been snoozed this many times, the next attempt warns.
  static let warningThreshold = 3

  static func routeForCount(_ count: Int) -> SnoozeRoute {
    count >= warningThreshold ? .warning : .picker
  }
}
