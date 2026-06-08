import Foundation
import WidgetKit

/// Debounces widget timeline reloads so a burst of dose writes triggers at most
/// one `WidgetCenter.reloadAllTimelines()` per `debounceSecs`.
///
/// An `actor` (not a lock, not `@MainActor`) so `scheduleReload()` is safe to
/// call from any isolation as a fire-and-forget side effect. Each call cancels
/// and restarts a `Task.sleep`, so only the last call in a burst fires.
///
/// Lives in the watch-app target only — it links WidgetKit and must not leak
/// into the iOS app or `Shared/` (where `DoseEventWriter` stays WidgetKit-free).
///
/// INTEGRATION POINT: when the watch receives **inbound** dose events from the
/// iPhone (the Log tab, §6.4) via `WatchConnectivityCoordinator`'s file-receive
/// merge, that merge should also `scheduleReload()` so the complication reflects
/// a phone-logged dose before the next background refresh. That merge path is in
/// `Shared/` (compiled for iOS too), so it can't reference this watch-only type
/// directly; bridging it (e.g. a `NotificationCenter` post observed here) is left
/// as a follow-up. Until then, inbound phone doses surface on the next
/// background refresh (~15 min) or app open.
public actor WidgetReloadCoordinator {
  public static let shared = WidgetReloadCoordinator()

  private let onReload: @Sendable () -> Void
  private let debounceSecs: TimeInterval
  private var pendingTask: Task<Void, Never>?

  /// - Parameters:
  ///   - debounceSecs: quiet window before a scheduled reload fires.
  ///   - onReload: the reload side effect. Injectable so tests can count calls
  ///     without the unmockable `WidgetCenter` singleton.
  public init(
    debounceSecs: TimeInterval = 2.0,
    onReload: @Sendable @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
  ) {
    self.debounceSecs = debounceSecs
    self.onReload = onReload
  }

  /// Coalesces rapid calls: each restarts the timer, so only the last call in a
  /// burst fires `onReload` (after `debounceSecs` of quiet).
  public func scheduleReload() {
    pendingTask?.cancel()
    let secs = debounceSecs
    let reload = onReload
    pendingTask = Task {
      do {
        try await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
      } catch {
        return // cancelled by a newer scheduleReload()
      }
      reload()
    }
  }

  /// Immediate reload that also cancels any pending debounced one — for the
  /// background-refresh handler, which wants a guaranteed reload now.
  public func reloadNow() {
    pendingTask?.cancel()
    pendingTask = nil
    onReload()
  }
}
