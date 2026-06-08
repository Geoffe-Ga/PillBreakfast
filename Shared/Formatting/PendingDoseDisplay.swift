/// Pure pending-count display mapping; lives in `Shared/` so it's CI-tested (the `WatchAppWidgets` extension has no test target yet — see #48).
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
