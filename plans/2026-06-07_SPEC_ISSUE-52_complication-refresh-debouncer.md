# SPEC — Issue #52: Background-Refresh Debouncer Keeps Complication Current After Dose Writes

| Field | Value |
|---|---|
| Issue | #52 |
| Phase | 7 — Widgets & Complication |
| Labels | `spec-decomposition`, `edges`, `phase-7-widgets`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #8 |
| Predecessor | #51 (LogNextDoseIntent) |
| Closes | Phase 7 gate |

---

## 1. Summary

This issue wires `WidgetCenter.shared.reloadAllTimelines()` into every dose-write path in the main watch app (`DoseEventWriter` call sites), adds a `WidgetReloadCoordinator` actor that debounces rapid consecutive reloads to at most one per 2 seconds, and registers a `WKApplicationRefreshBackgroundTask` handler (`BackgroundRefreshHandler`) on the watch that pre-computes and refreshes the complication timeline on a background schedule. Together these ensure the complication pending count decrements within ~60 seconds of a dose being logged — satisfying the Phase 7 gate.

---

## 2. Problem Statement / Motivation

After #51 lands, the widget family works and the intent logs doses correctly. However, widgets update only when their timeline's `policy` says to, or when `WidgetCenter.shared.reloadAllTimelines()` is explicitly called. As of #51, that call happens only in `LogNextDoseIntent.perform()` (the widget-originated log path). Doses logged via the main watch app — the primary path — do not trigger any reload. The Phase 7 gate specifically requires: "See pending count update in real time after a dose is logged." Without this issue, the complication will show a stale count until the next scheduled timeline refresh (up to 15 minutes per the stub policy, longer per the `.atEnd` policy in #49).

Additionally, the watchOS background execution model allows apps to register for periodic background refreshes (`WKApplicationRefreshBackgroundTask`), which can call `WidgetCenter.shared.reloadAllTimelines()` even when the app is not in the foreground. This is the mechanism that keeps the complication accurate between user interactions.

---

## 3. Goals and Non-Goals

**Goals:**
- Implement `WidgetReloadCoordinator` (`Shared/Background/WidgetReloadCoordinator.swift`): an `actor` with a `scheduleReload()` method that debounces calls to `WidgetCenter.shared.reloadAllTimelines()` — at most once per 2 seconds, coalescing rapid successive writes.
- Invoke `WidgetReloadCoordinator.shared.scheduleReload()` from every `DoseEventWriter.writeDoseEvent(...)` call site in the watch app: `TapThroughQueueView`, `PRNQuantityPickerView`, `LogAnytimeConfirmView`, and any other view that calls `DoseEventWriter`.
- Invoke `WidgetReloadCoordinator.shared.scheduleReload()` from `DoseEventBatchMerger` (the watch-side receiver of incoming `DoseEvent`s synced from iPhone, if one exists — verify in codebase; if not yet implemented, add a note in the coordinator that this is a future integration point).
- Implement `BackgroundRefreshHandler` (`WatchApp Watch App/Bootstrap/BackgroundRefreshHandler.swift`): registers and handles `WKApplicationRefreshBackgroundTask`, calls `WidgetCenter.shared.reloadAllTimelines()`, and schedules the next background refresh.
- Register `BackgroundRefreshHandler` in the watch app's bootstrap (`PillBreakfast_Watch_AppApp.init()` or `body`).
- Unit test: writing two `DoseEvent`s within 2 seconds triggers exactly one reload call, not two.
- Manual checklist: log a dose, observe the complication pending count decrement within 60 seconds.

**Non-Goals:**
- New widget surfaces or complication families.
- iOS-side background refresh (iOS has its own `BGAppRefreshTask` mechanism; that is a future issue).
- Changing the `TimelineProvider.getTimeline` policy — the reload-on-write approach supersedes the scheduled policy for dose-driven transitions; the `.atEnd` policy is a fallback for day-boundary rollovers.
- Modifying `DoseEventWriter` itself to call `WidgetCenter` — the writer is in `Shared/` and must not import `WidgetKit` (WidgetKit is not available on all targets that include `Shared/`). The reload is the caller's responsibility, coordinated through `WidgetReloadCoordinator`.

---

## 4. Background and Current State

**Existing dose-write call sites in the watch app:**

From codebase exploration, `DoseEventWriter.writeDoseEvent(...)` is called in:
- `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — the `log(_, _, status:)` private method.
- `PillBreakfast Watch App Watch App/PRNSection/PRNQuantityPickerView.swift` — PRN dose confirmation.
- `PillBreakfast Watch App Watch App/AnytimeLog/LogAnytimeConfirmView.swift` — the anytime/scheduled log path.

Each of these must call `WidgetReloadCoordinator.shared.scheduleReload()` after a successful `DoseEventWriter.writeDoseEvent(...)`.

**`DoseEventBatchMerger`:** Not found in the current codebase by the `Glob` and `Grep` search. The issue body references "DoseEventBatchMerger" — this may be a planned type or may have a different name. The actual watch-side inbound sync path merges incoming `DoseEvent`s from the iPhone via `WatchConnectivityCoordinator`. Search for the type that applies inbound `DoseEventBatchDTO` on the watch — if it exists, add a reload call there too. If it does not yet exist, document the integration point in `WidgetReloadCoordinator` with a `// TODO:` comment.

**`DoseEventBatchDTO`** exists at `Shared/Sync/DoseEventBatchDTO.swift` — this is the wire format for iPhone → watch DoseEvent transfer. The corresponding receiver on the watch side must be identified before implementation.

**`WidgetCenter`:** Available in both the watch app target and the widget extension target. It is not available in `Shared/` files (WidgetKit is not linked to the shared module). This is why the coordinator belongs in a target that links WidgetKit.

**`WKApplicationRefreshBackgroundTask`:** The watchOS mechanism for periodic background execution. The watch app must declare `Background Modes → Background App Refresh` in its capabilities (verify this is already set up from Phase 0 / the SPEC §10 Phase 0 instructions; if not, it must be added). The background task handler is registered via `WKApplication.shared().scheduleBackgroundRefresh(preferredFireDate:userInfo:scheduledCompletion:)`.

---

## 5. Detailed Design

### 5.1 `WidgetReloadCoordinator`

This type is placed in `Shared/Background/WidgetReloadCoordinator.swift` but is compiled only into targets that link WidgetKit — specifically the `WatchAppWidgets` extension and the watch app. It must NOT be added to the iOS target (WidgetKit is available on iOS, but `WidgetCenter.shared.reloadAllTimelines()` in an iOS context would reload iOS widgets, which don't exist in this app — harmless but unnecessary). It must NOT be added to `Shared/` with implicit iOS target membership unless WidgetKit is explicitly linked on iOS. The safest approach: place the file in `Shared/Background/` but add it to target membership for the watch app and extension only.

```swift
import Foundation
import WidgetKit
import os

/// Debounces WidgetCenter timeline reloads so that a rapid burst of DoseEvent
/// writes (e.g. logging a full morning queue in 10 seconds) issues at most one
/// reloadAllTimelines() call per `debounceSecs` interval.
///
/// Actor isolation prevents data races on the pending-reload state.
public actor WidgetReloadCoordinator {
    public static let shared = WidgetReloadCoordinator()

    /// Minimum interval between successive reloads. 2 seconds: fast enough to
    /// feel real-time on the Phase 7 gate test, slow enough to respect the
    /// watchOS complication reload budget (Apple documents a per-hour budget of
    /// roughly 50 reloads for watchOS complications; at 2s debounce a 12-dose
    /// morning session costs 1–2 reloads, not 12).
    public let debounceSecs: TimeInterval

    private var pendingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "WidgetReload")

    public init(debounceSecs: TimeInterval = 2.0) {
        self.debounceSecs = debounceSecs
    }

    /// Schedule a reload. Multiple calls within `debounceSecs` collapse into one.
    /// Safe to call from any actor — the actor hop is implicit.
    public func scheduleReload() {
        // Cancel any pending debounce task; the new call restarts the timer.
        pendingTask?.cancel()
        pendingTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceSecs * 1_000_000_000))
            } catch {
                // Task was cancelled (another scheduleReload() arrived) — do nothing.
                return
            }
            // Task.sleep succeeded — the debounce window expired without another call.
            WidgetCenter.shared.reloadAllTimelines()
            logger.debug("WidgetCenter.reloadAllTimelines() fired after debounce.")
        }
    }

    /// Immediately reload, bypassing the debounce. Used by BackgroundRefreshHandler
    /// where we want to ensure the reload happens before the background task expires.
    public func reloadNow() {
        pendingTask?.cancel()
        pendingTask = nil
        WidgetCenter.shared.reloadAllTimelines()
        logger.debug("WidgetCenter.reloadAllTimelines() fired immediately (reloadNow).")
    }
}
```

**Why an `actor` and not `@MainActor` or a struct with a lock:** `WidgetReloadCoordinator` manages mutable state (`pendingTask`) and must be callable from any actor. Using `actor` isolation eliminates the need for a manual lock and plays well with Swift 6 strict concurrency. The `Task.sleep` debounce pattern is idiomatic Swift concurrency — no `DispatchWorkItem` or `Timer` needed.

**Why not put the `WidgetCenter.reloadAllTimelines()` call inside `DoseEventWriter`:** `DoseEventWriter` lives in `Shared/` and must stay WidgetKit-free. The writer is a pure persistence primitive; side effects (reload, batch transfer, WatchConnectivity) are the caller's responsibility. This separation keeps `Shared/` testable without WidgetKit linking.

### 5.2 Integration Points — Existing Dose-Write Call Sites

Three files in the watch app call `DoseEventWriter.writeDoseEvent(...)` and must be updated to call `WidgetReloadCoordinator.shared.scheduleReload()` after a successful write:

**`TapThroughQueueView.swift` — `log(_ dose:_ medication:status:)` method:**

```swift
// After the existing DoseEventBatchTransfer.transfer([event]) call:
Task {
    await WidgetReloadCoordinator.shared.scheduleReload()
}
```

Note: `TapThroughQueueView` is `@MainActor` (it is a SwiftUI `View`). `WidgetReloadCoordinator.scheduleReload()` is an `actor` method — calling it from `@MainActor` requires an `await`. Wrapping in `Task { await ... }` fires-and-forgets, which is appropriate here (the reload is a side effect, not part of the view's state machine).

**`PRNQuantityPickerView.swift` — wherever `DoseEventWriter.writeDoseEvent(...)` is called:**

Apply the same `Task { await WidgetReloadCoordinator.shared.scheduleReload() }` pattern after the successful write.

**`LogAnytimeConfirmView.swift` — wherever `DoseEventWriter.writeDoseEvent(...)` is called:**

Same pattern.

**DoseEventBatchMerger (if it exists):** Search for the type that applies inbound `DoseEventBatchDTO`. If found, add the reload call there. If not yet implemented, add a `// INTEGRATION POINT: call WidgetReloadCoordinator.shared.scheduleReload() here when implemented.` comment in the `WidgetReloadCoordinator` source.

### 5.3 `BackgroundRefreshHandler`

```swift
import Foundation
import WatchKit
import WidgetKit
import os

/// Registers and handles WKApplicationRefreshBackgroundTask so the complication
/// can refresh on a schedule even when the app is not in the foreground.
///
/// Registered once at app launch. Each handler invocation reloads all widget
/// timelines and schedules the next background refresh.
@MainActor
public final class BackgroundRefreshHandler: NSObject {
    public static let shared = BackgroundRefreshHandler()

    /// The background task identifier. Must match the value in Info.plist under
    /// WKBackgroundModes if that key is required (verify in Xcode 26 SDK).
    public static let taskIdentifier = "com.creekmasons.pillbreakfast.background-refresh"

    /// How frequently to schedule background refreshes. 15 minutes is the
    /// minimum Apple will honor on watchOS; requesting more frequently has no
    /// effect. At 15 min cadence the complication is never more than 15 min
    /// stale in the absence of a foreground dose write.
    static let refreshInterval: TimeInterval = 15 * 60

    private let logger = Logger(
        subsystem: "com.creekmasons.pillbreakfast",
        category: "BackgroundRefresh"
    )

    private override init() {}

    /// Call once from the watch app's init or scene delegate.
    public func register() {
        scheduleNextRefresh()
    }

    /// Called by the watch app's `handle(_ backgroundTasks:)` when a
    /// WKApplicationRefreshBackgroundTask fires.
    public func handle(_ task: WKApplicationRefreshBackgroundTask) {
        logger.debug("BackgroundRefreshHandler: handling WKApplicationRefreshBackgroundTask.")
        // Reload all widget timelines immediately (no debounce — this IS the
        // background budget tick; we want the reload to happen before the task expires).
        Task {
            await WidgetReloadCoordinator.shared.reloadNow()
            scheduleNextRefresh()
            // Mark the task complete so the system releases the background execution time.
            task.setTaskCompletedWithSnapshot(false)
        }
    }

    private func scheduleNextRefresh() {
        let fireDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        WKApplication.shared().scheduleBackgroundRefresh(
            preferredFireDate: fireDate,
            userInfo: nil
        ) { [weak self] error in
            if let error {
                self?.logger.error(
                    "Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
```

**Registration in `PillBreakfast_Watch_App_Watch_AppApp`:**

```swift
// In the existing app struct's init():
init() {
    WatchConnectivityCoordinator.shared.activate()
    _ = CrashReporting.shared
    BackgroundRefreshHandler.shared.register()  // <-- add this
}
```

**Background task routing in the watch app delegate:** The watch app uses `@WKApplicationDelegateAdaptor` for `NotificationDelegate`. Background task handling for `WKApplicationRefreshBackgroundTask` goes through the same delegate pattern. The watch app struct or its delegate must implement `handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>)`:

```swift
// In NotificationDelegate or a new WatchAppDelegate, add:
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        switch task {
        case let refreshTask as WKApplicationRefreshBackgroundTask:
            BackgroundRefreshHandler.shared.handle(refreshTask)
        default:
            task.setTaskCompletedWithSnapshot(false)
        }
    }
}
```

If the existing `NotificationDelegate` does not implement `handle(_:)`, add the method there. Confirm that `WKApplicationDelegate` includes this method in watchOS 26 (it does, per watchOS 3+ documentation).

### 5.4 Debounce Budget Analysis

The watchOS complication system imposes a per-hour reload budget. Apple's documentation indicates this is approximately 50 reloads per hour for the active complication. At a 2-second debounce:
- Morning session: 12 doses logged in ~5 minutes → at most one reload per 2 seconds → at most 150 reloads if every dose is 2 seconds apart. This is over budget if truly spaced at exactly 2s. In practice, the user takes ~5–10 seconds per dose in the tap-through flow. At 5s between doses, 12 doses = 12 individual scheduleReload() calls each debounced to 2s → the debounce timer resets on each call, so if dose N+1 arrives within 2s of dose N, only the last one fires. For a 10-dose session at 5s intervals, the debounce fires every time (each is >2s apart), producing 10 reloads. Still under 50/hour.
- At 2s debounce with a 10-dose morning session taking 60 seconds: at most 30 reloads/hour (if the timing is adversarial). Well within budget.
- The 15-minute background refresh adds 4 reloads/hour — trivial.

The 2-second debounce is the correct balance: fast enough to feel immediate (the complication updates within ~2s of the last dose), slow enough to avoid budget exhaustion.

### 5.5 Swift 6 Concurrency

- `WidgetReloadCoordinator` is an `actor` — all methods require `await`. Call sites use `Task { await ... }` to fire-and-forget from `@MainActor` contexts (the SwiftUI views). This is correct: the reload is a side effect, not a state update the view needs to observe.
- `BackgroundRefreshHandler` is `@MainActor` — it runs on the main actor. The `Task { await WidgetReloadCoordinator.shared.reloadNow() ... }` hop is explicit and sound.
- `Task.sleep` inside `WidgetReloadCoordinator.scheduleReload()` respects task cancellation — cancelled tasks do not fire the reload. This is the correct debounce behavior.
- `WKApplication.shared().scheduleBackgroundRefresh(...)` is a non-async completion-based API. The `weak self` capture is required to avoid a retain cycle through the callback closure. Since `BackgroundRefreshHandler` is a `@MainActor` class, the callback must either `Task { @MainActor in ... }` or be checked for actor isolation — in the design above, the completion handler only logs an error, which does not require main-actor access.

---

## 6. UX and Visual Design

No new visible UI. The complication and Smart Stack widget are the UX; this issue makes them stay accurate. The user experience of this issue is the Phase 7 gate: "Add complication to watch face. See pending count update in real time after a dose is logged." — pending count decrements within ~60 seconds of a dose being logged (in practice, within ~2 seconds via the debouncer if the app is in the foreground, and within 15 minutes via the background refresh if not).

---

## 7. Edge Cases and Failure Modes

| Scenario | Handling |
|---|---|
| `scheduleReload()` is called but the watch app is terminated before the 2-second debounce fires | The `Task` is cancelled when the process exits. No reload fires. The background refresh handler will fire within 15 min and reload. Acceptable. |
| `WKApplication.shared().scheduleBackgroundRefresh(...)` fails | Log at `.error` level. The next foreground launch will call `register()` again, rescheduling. No crash. |
| `WKApplicationRefreshBackgroundTask` fires but `reloadAllTimelines()` is too slow and the task expires before completion | `setTaskCompletedWithSnapshot(false)` is called inside a `Task` — if the OS kills the process before the task completes, the system logs it. The `reloadNow()` call is synchronous from `WidgetCenter`'s perspective; the actual timeline rebuild is async in the extension process. The task can safely be marked complete after calling `WidgetCenter.shared.reloadAllTimelines()`, which returns immediately (the rebuild is async in the extension). |
| Background refresh is not granted by the OS (power saver mode, low battery) | The system may delay or skip background refreshes at its discretion. The complication shows stale data until the next foreground interaction or the next granted refresh. Document this in Settings tab ("Complication may lag in Low Power Mode"). |
| `WidgetReloadCoordinator.shared.scheduleReload()` called from an `async` context that is not the main actor | Fine — `actor` methods accept calls from any actor via `await`. The hop is automatic. |
| Two concurrent `scheduleReload()` calls from different tasks | The `actor` serializes them. The second cancels the first's `pendingTask` and resets the 2-second window. Exactly the desired behavior. |
| `reloadAllTimelines()` is called with no widgets installed | No-op from WidgetKit's perspective. Safe. |
| Multiple dose writes from `DoseEventBatchMerger` (incoming sync batch from iPhone) | All write events flow through `scheduleReload()` → debouncer → one reload. The debounce window is reset on each call, so a 10-dose sync batch arriving over 500ms → one reload fires 2s after the last write. Correct. |

---

## 8. Testing Strategy

**Unit tests (`PillBreakfastTests` or `WatchAppWidgetsTests`):**

The core testable invariant: writing two events within 2 seconds triggers one reload, not two.

```swift
// Pseudocode for the unit test:
func testDebounceCoalescesTwoRapidCalls() async throws {
    var reloadCount = 0
    // Inject a mock WidgetCenter or count calls via a seam.
    // WidgetCenter cannot be easily mocked because it is a final class;
    // introduce a protocol seam:

    // WidgetReloadCoordinator in tests uses a closure-based reload sink:
    let coordinator = WidgetReloadCoordinator(debounceSecs: 0.1) // fast for tests

    // Patch the reload action — see §8 note on seam design.
    var reloadCount = 0
    coordinator.onReload = { reloadCount += 1 }

    await coordinator.scheduleReload()
    await coordinator.scheduleReload() // arrives within 0.1s debounce window

    // Wait for debounce to fire.
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms > 100ms debounce

    XCTAssertEqual(reloadCount, 1)
}
```

**Seam design for `WidgetCenter`:** `WidgetCenter.shared` is a concrete class that cannot be subclassed or replaced in tests. Two options:
1. **Closure injection:** `WidgetReloadCoordinator` accepts an `onReload: @Sendable () -> Void` parameter in `init`, defaulting to `{ WidgetCenter.shared.reloadAllTimelines() }`. Tests pass a counting closure. Production uses the default.
2. **Protocol wrapper:** Define `protocol WidgetReloading { func reloadAllTimelines() }` and pass it to the coordinator. `WidgetCenter` is extended to conform. Tests pass a stub.

Option 1 (closure injection) is simpler. The production `WidgetReloadCoordinator.shared` static property uses the default closure.

Updated `WidgetReloadCoordinator` init:

```swift
public actor WidgetReloadCoordinator {
    public static let shared = WidgetReloadCoordinator()

    public let debounceSecs: TimeInterval
    private let onReload: @Sendable () -> Void
    private var pendingTask: Task<Void, Never>?

    public init(
        debounceSecs: TimeInterval = 2.0,
        onReload: @Sendable @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.debounceSecs = debounceSecs
        self.onReload = onReload
    }
    // ... rest unchanged, calling onReload() instead of WidgetCenter directly
}
```

**Additional unit tests:**
- Single call: fires exactly one reload after `debounceSecs` (within tolerance).
- Two calls > `debounceSecs` apart: fires two reloads.
- `reloadNow()`: fires immediately (no sleep), cancels any pending debounce.
- `BackgroundRefreshHandler.handle(_:)`: assert `WidgetCenter.reloadAllTimelines()` is called and `scheduleNextRefresh()` is called (use the closure seam, inject via `BackgroundRefreshHandler`'s init or a testable method).

**Manual checklist (from issue body):**
1. On the Apple Watch (simulator or device), add the circular complication to the watch face.
2. Confirm it shows the correct pending count (e.g. "2" for two morning doses).
3. Log one dose via the main watch app tap-through queue.
4. Observe the complication count decrement within 60 seconds (in practice ~2 seconds in foreground).
5. Confirm the Phase 7 gate: "Add complication to watch face. See pending count update in real time after a dose is logged."

---

## 9. Performance and Resource Budget

- **Debounce cost:** One `Task.sleep(nanoseconds:)` per burst. Negligible CPU. No timers, no `DispatchQueue` retained.
- **Reload cost:** `WidgetCenter.shared.reloadAllTimelines()` is a synchronous call that returns immediately; the actual rebuild runs in the extension process. From the watch app's perspective, cost is approximately zero.
- **Background refresh task:** Runs for a few milliseconds to call `reloadAllTimelines()` and reschedule. Well within the background task time budget.
- **Reload budget:** See §5.4 analysis. At most ~30 reloads/hour in an adversarial morning session; the 15-min background refresh adds 4/hour. Total ~34/hour, comfortably under the ~50/hour watchOS complication budget.
- **Memory:** `WidgetReloadCoordinator` holds one optional `Task`. No significant allocation.

---

## 10. Risks and Open Questions

| Risk | Likelihood | Mitigation |
|---|---|---|
| `WKApplicationRefreshBackgroundTask` is not granted by the OS often enough for the 60-second gate | Low | The gate is primarily satisfied by the foreground debouncer. Background refresh is a secondary guarantee for the "app not open" case. |
| `DoseEventBatchMerger` does not exist; the watchOS inbound sync receiver is unidentified | Medium | Investigate `WatchConnectivityCoordinator` on the watch side; if it applies incoming `DoseEvent`s directly to the SwiftData store, add the `scheduleReload()` call there. If the receiver doesn't exist yet (Phase 6 issue), document the integration point with a comment. |
| `Task { await WidgetReloadCoordinator.shared.scheduleReload() }` pattern in SwiftUI view methods creates unstructured tasks that aren't tied to the view's lifecycle | Low | These tasks are fire-and-forget — they have no observable state. The 2-second sleep is short enough that the task will complete before any view is unmounted. If the view IS unmounted, the task's completion (firing `WidgetCenter.reloadAllTimelines()`) is harmless. |
| `WidgetCenter.shared.reloadAllTimelines()` called from the widget extension's `LogNextDoseIntent.perform()` (#51) AND from the watch app's debouncer (#52) for the same dose write | Low | Not possible for the same log event: widget-originated logs go through the extension; app-originated logs go through the watch app. They may both reload timelines within a short window if a user taps the widget and then immediately opens the app — the resulting two reloads are harmless (the count is already correct after the first). |
| `WKApplication.shared()` is only available inside the watch app process | Not a risk | `BackgroundRefreshHandler` is in `WatchApp Watch App/Bootstrap/` — it is never compiled into the extension. |
| Closure injection breaks `WidgetReloadCoordinator.shared` being a static `let` (actor stored properties) | Low | In Swift 6, a `static let` actor property can capture a `@Sendable` closure. Verify the compiler accepts `@Sendable @escaping () -> Void` as an actor stored property — it should, since the closure itself is `Sendable`. |

**Open question resolved:** The issue body mentions "Debounce at 2 seconds — fast enough to feel real-time on the gate test, slow enough to not blow the complication budget." This spec confirms 2 seconds is the correct value per the budget analysis in §5.4.

**Open question for post-Phase-7:** Should `WidgetReloadCoordinator.scheduleReload()` also be called from the iPhone companion app? The iPhone app does not own `WidgetKit`-linked widgets in this project (there is no iOS widget extension), so calling `WidgetCenter.shared.reloadAllTimelines()` from the iPhone would be a no-op. Do not add this unless an iOS widget is added in a future phase.

---

## 11. Decomposition Hints

Single PR. Implementation sequence:
1. Search `WatchConnectivityCoordinator.swift` and related watch-side files to identify any `DoseEvent` inbound-sync receiver (potential `DoseEventBatchMerger` analog).
2. Implement `WidgetReloadCoordinator` with closure injection seam.
3. Update the three existing `DoseEventWriter` call sites in the watch app.
4. Implement `BackgroundRefreshHandler`.
5. Register `BackgroundRefreshHandler` in the watch app bootstrap.
6. Wire background task routing in `NotificationDelegate` (or a new delegate).
7. Write unit tests.
8. Run manual checklist.

---

## 12. Acceptance Criteria / Done-Done

- [ ] `WidgetReloadCoordinator.scheduleReload()` debounce unit test: two calls within 2 seconds → one reload (unit test passes).
- [ ] `WidgetReloadCoordinator.reloadNow()` unit test: fires immediately, cancels pending debounce.
- [ ] `TapThroughQueueView`, `PRNQuantityPickerView`, `LogAnytimeConfirmView` each call `WidgetReloadCoordinator.shared.scheduleReload()` after a successful `DoseEventWriter.writeDoseEvent(...)`.
- [ ] `BackgroundRefreshHandler` is registered at watch app launch and handles `WKApplicationRefreshBackgroundTask`.
- [ ] Manual gate: log a dose on the watch → complication pending count decrements within 60 seconds.
- [ ] Both watch app and widget extension build under Swift 6 strict concurrency with zero warnings.
- [ ] `pre-commit run --all-files` clean.
- [ ] Phase 7 gate satisfied (confirmed in PR description with manual test evidence).
- [ ] PR references `Closes #52`, `Refs #8`.

---

## 13. References

- SPEC §7.4 — "Shows count of pending doses for current window."
- SPEC §10 Phase 7 gate — "See pending count update in real time after a dose is logged."
- `Shared/Logging/DoseEventWriter.swift` — `@MainActor writeDoseEvent(...)`.
- `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift` — `log(_:_:status:)`.
- `PillBreakfast Watch App Watch App/PRNSection/PRNQuantityPickerView.swift` — PRN dose write.
- `PillBreakfast Watch App Watch App/AnytimeLog/LogAnytimeConfirmView.swift` — anytime log write.
- `PillBreakfast Watch App Watch App/Bootstrap/NotificationDelegate.swift` — existing delegate; add `handle(_:)` here.
- `PillBreakfast Watch App Watch App/PillBreakfast_Watch_AppApp.swift` — bootstrap entry point.
- Predecessor: `2026-06-07_SPEC_ISSUE-51_log-next-dose-intent.md`.
- Apple: "Keeping a Widget Up To Date" — `WidgetCenter.reloadAllTimelines()`.
- Apple: "Background Tasks" (WatchKit / WKApplicationRefreshBackgroundTask).
- Apple: "Configuring background execution modes" (watchOS Capabilities).
