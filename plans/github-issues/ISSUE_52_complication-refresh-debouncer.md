## Role

You are a senior watchOS engineer closing the Phase 7 gate: making the complication and Smart Stack stay current after dose writes. You will add a debounced widget-reload coordinator, wire it into every watch-app dose-write call site, and register a background-refresh handler so the complication updates even when the app is closed.

## Goal

Implement `WidgetReloadCoordinator` (an `actor` debouncing `WidgetCenter.shared.reloadAllTimelines()` to at most one call per 2 seconds), call `scheduleReload()` after every successful `DoseEventWriter.writeDoseEvent(...)` in the watch app, and implement + register `BackgroundRefreshHandler` (`WKApplicationRefreshBackgroundTask`) so timelines refresh on a ~15-minute background cadence. The result: the complication's pending count decrements within ~60 seconds of a dose being logged (within ~2 seconds in the foreground).

## Context

- **Parent epic:** #52 (this issue is the atomic Phase 7 closer; the spec's §11 specifies a single PR).
- **Predecessor:** #51 (`LogNextDoseIntent.perform()` already calls `reloadAllTimelines()` for the widget-originated log path; the app-originated paths do not yet trigger any reload).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-52_complication-refresh-debouncer.md` §5.1 (`WidgetReloadCoordinator`), §5.2 (call sites), §5.3 (`BackgroundRefreshHandler` + routing), §5.4 (budget), §5.5 (concurrency), §8 (tests + seam). SPEC §10 Phase 7 gate.
- **Files involved:**
  - `Shared/Background/WidgetReloadCoordinator.swift` (new) — the actor; added to the **watch app + extension** target membership only (NOT iOS — it links WidgetKit).
  - `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — `log(_:_:status:)` after the existing `DoseEventBatchTransfer.transfer([event])`.
  - `PillBreakfast Watch App Watch App/PRNSection/PRNQuantityPickerView.swift` — after the PRN write.
  - `PillBreakfast Watch App Watch App/AnytimeLog/LogAnytimeConfirmView.swift` — after the anytime/scheduled write.
  - `PillBreakfast Watch App Watch App/Bootstrap/BackgroundRefreshHandler.swift` (new) — `@MainActor` handler + scheduler.
  - `PillBreakfast Watch App Watch App/Bootstrap/NotificationDelegate.swift` — add `handle(_ backgroundTasks:)` routing.
  - `PillBreakfast_Watch_App_Watch_AppApp` (`…/PillBreakfast_Watch_AppApp.swift`) — call `BackgroundRefreshHandler.shared.register()` in `init()`.
  - Watch app capabilities/`Info.plist` — confirm Background App Refresh mode is enabled; add if missing.
- **Prior decisions (locked):**
  - `WidgetReloadCoordinator` is an `actor` (not `@MainActor`, not a lock) with a `Task.sleep` debounce; `scheduleReload()` cancels and restarts the pending task; `reloadNow()` bypasses the debounce for the background handler.
  - 2-second debounce — fast enough for the gate, under the ~50 reloads/hour complication budget (see §5.4 analysis).
  - **`DoseEventWriter` stays WidgetKit-free** — it lives in `Shared/` and must not import WidgetKit. The reload is the caller's responsibility via the coordinator. Do not move the reload into the writer.
  - Call sites are `@MainActor` SwiftUI views → call via `Task { await WidgetReloadCoordinator.shared.scheduleReload() }` (fire-and-forget side effect).
  - Investigate the watch-side inbound-sync receiver for `DoseEventBatchDTO` (`Shared/Sync/DoseEventBatchDTO.swift`; check `WatchConnectivityCoordinator` on the watch). If a merger exists, call `scheduleReload()` there too; if not, leave a documented `// INTEGRATION POINT:` comment in `WidgetReloadCoordinator` — do not invent a type.
  - Test seam: `WidgetCenter` is final/unmockable → inject `onReload: @Sendable @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }` into the coordinator's `init`; `.shared` uses the default; tests pass a counting closure with a short `debounceSecs`.
  - `BackgroundRefreshHandler` is `@MainActor`; `handle(_:)` calls `reloadNow()`, reschedules, then `setTaskCompletedWithSnapshot(false)`; `scheduleNextRefresh()` uses `WKApplication.shared().scheduleBackgroundRefresh(...)` with `[weak self]`.

## Output Format

A single PR containing:

- [ ] `WidgetReloadCoordinator` actor: `scheduleReload()` (debounced via cancellable `Task.sleep`), `reloadNow()` (immediate, cancels pending), closure-injection seam, `.shared` singleton. Added to watch app + extension targets only.
- [ ] `scheduleReload()` called after a successful `DoseEventWriter.writeDoseEvent(...)` in `TapThroughQueueView`, `PRNQuantityPickerView`, and `LogAnytimeConfirmView` (via `Task { await … }`).
- [ ] Inbound-sync receiver handled: a `scheduleReload()` call if a merger exists, else a documented integration-point comment.
- [ ] `BackgroundRefreshHandler` (`@MainActor`): `register()`, `handle(_:)`, `scheduleNextRefresh()` (~15 min).
- [ ] `BackgroundRefreshHandler.shared.register()` called in the watch app `init()`; `handle(_ backgroundTasks:)` routing added to `NotificationDelegate`; Background App Refresh capability confirmed/enabled.
- [ ] Tests: two `scheduleReload()` calls within the debounce window → exactly one reload (via the seam); a single call → one reload after the interval; two calls > interval apart → two reloads; `reloadNow()` → immediate + cancels pending.

## Examples

```swift
public actor WidgetReloadCoordinator {
    public static let shared = WidgetReloadCoordinator()
    private let onReload: @Sendable () -> Void
    private var pendingTask: Task<Void, Never>?
    public let debounceSecs: TimeInterval

    public init(
        debounceSecs: TimeInterval = 2.0,
        onReload: @Sendable @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.debounceSecs = debounceSecs
        self.onReload = onReload
    }

    public func scheduleReload() {
        pendingTask?.cancel()
        pendingTask = Task {
            do { try await Task.sleep(nanoseconds: UInt64(debounceSecs * 1_000_000_000)) }
            catch { return } // cancelled by a newer call
            onReload()
        }
    }
}
```

## Constraints

**Scope fence:** Reload coordination + call-site wiring + background refresh only. **No** new widget surfaces or families. **No** iOS-side background refresh (`BGAppRefreshTask` is a future issue). **No** change to any `TimelineProvider.getTimeline` policy. **Do not** add WidgetKit to `DoseEventWriter` or `Shared/` at large; keep the coordinator's target membership to the watch app + extension.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Logging a dose on the watch (tap-through, PRN, or anytime) decrements the complication's pending count within ~60 seconds (within ~2s in the foreground) on the simulator. The watch app and extension still build and run on the paired simulator. Existing dose-logging flows are unchanged except for the added reload side effect.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] Phase 7 gate satisfied — PR description includes manual test evidence (log a dose → complication decrements within 60s).
- [ ] PR opened with `Closes #52` and `Refs #8`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `edges`, `phase-7-widgets`, `watch`, `concurrency`
