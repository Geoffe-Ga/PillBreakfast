import Foundation

/// Presentation of a pending-dose count for the watch complication (and any
/// surface that shows "how many doses are due now").
///
/// Pure value→string mapping, kept in `Shared/` so it is unit-tested in the main
/// suites even though its first consumer — `PendingDoseEntry` — lives in the
/// `WatchAppWidgets` extension, which has no dedicated test target yet (#48
/// deferred it). `Shared/` is compiled into the extension, so the entry can
/// delegate here while the logic stays covered by CI.
public nonisolated enum PendingDoseDisplay {
  /// `nil` → `"--"` (unknown / stub), `0` → `"✓"` (all caught up), positive → the count.
  public static func text(forCount count: Int?) -> String {
    guard let count else { return "--" }
    return count == 0 ? "✓" : "\(count)"
  }

  /// Whether any dose is due now.
  public static func hasPending(_ count: Int?) -> Bool {
    (count ?? 0) > 0
  }
}
