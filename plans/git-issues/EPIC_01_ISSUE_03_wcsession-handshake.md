## Role

You are a senior Apple-platforms engineer wiring the WatchConnectivity layer for PillBreakfast. You understand `WCSession` lifecycle, the delegate methods, and Swift 6 actor isolation around `@MainActor` UI updates from `WCSessionDelegate` callbacks.

## Goal

Add a `WatchConnectivityCoordinator` actor on both targets that activates `WCSession.default` at app launch, conforms to `WCSessionDelegate`, and logs activation state transitions. Both targets must log `WCSession activated, state=.activated` within 5 seconds of launching the paired simulator pair. No payload is sent in this issue — that's EPIC 02.

## Context

- **Parent epic:** #1
- **Predecessor issue(s):** #EPIC_01_ISSUE_01_NUMBER (project scaffolding), #EPIC_01_ISSUE_02_NUMBER (SwiftData container so we know the App Group works).
- **SPEC section:** `plans/SPEC.md` §4 (Sync row) and §10 Phase 0 ("Stub `WCSession` setup on both sides; log handshake to console").
- **Files involved:**
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — the coordinator, an actor with `@MainActor` boundary for SwiftUI-facing state.
  - `iOSApp/iOSAppApp.swift` — instantiate and activate the coordinator at launch.
  - `WatchApp Watch App/WatchApp.swift` — same on the watch.
  - `Shared/Sync/WCSessionState+Display.swift` — a tiny extension turning `WCSessionActivationState` into a human-readable string for the placeholder view.
  - `PillBreakfastTests/WatchConnectivityCoordinatorTests.swift` — at minimum, asserts that the coordinator can be constructed and that calling `activate()` does not crash. (Full integration test on the simulator pair is the gate, not the unit test.)
- **Prior decisions (locked):**
  - WatchConnectivity is the sync channel (SPEC §4); not CloudKit, not a custom socket.
  - This issue does **not** send a payload. The first `updateApplicationContext` happens in EPIC_02_ISSUE_05.
  - SPEC §11 Phase 1 stretch skill: "WCSession lifecycle and reachability handling." Map the state machine explicitly in the coordinator.
- **State of the world:** EPIC_01_ISSUE_02 has landed. Both targets build and open the SwiftData container. No `WCSession` code exists yet.

## Output Format

A single PR containing:

- [ ] `WatchConnectivityCoordinator` with an `activate()` entry point and the four required `WCSessionDelegate` methods (`session(_:activationDidCompleteWith:error:)`, `sessionDidBecomeInactive(_:)`, `sessionDidDeactivate(_:)`, `session(_:didReceiveApplicationContext:)`).
- [ ] Activation triggered at app launch on both targets.
- [ ] Placeholder `RootView` updated to render `"Hello PillBreakfast · WC state: <state>"` using a published `@Observable` field on the coordinator (mainly so it's clear at-a-glance whether activation worked).
- [ ] A `os_log`-based logger writing to the `com.creekmasons.pillbreakfast` subsystem so the activation lines are findable in Console.app.
- [ ] A unit test on each target asserting the coordinator constructs and `activate()` is idempotent.

## Examples

`Shared/Sync/WatchConnectivityCoordinator.swift` (abridged):

```swift
import Foundation
import WatchConnectivity
import os.log

@MainActor
@Observable
public final class WatchConnectivityCoordinator: NSObject, WCSessionDelegate, Sendable {
    public static let shared = WatchConnectivityCoordinator()

    public private(set) var activationState: WCSessionActivationState = .notActivated
    public private(set) var lastError: String?

    private let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "WatchConnectivity")

    public func activate() {
        guard WCSession.isSupported() else {
            logger.warning("WCSession not supported on this device.")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        logger.info("WCSession activation requested.")
    }

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.lastError = error?.localizedDescription
            self.logger.info("WCSession activated, state=\(activationState.rawValue, privacy: .public)")
        }
    }

    // iOS-only delegate stubs:
    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) { logger.info("WCSession inactive.") }
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated; reactivating.")
        WCSession.default.activate()
    }
    #endif
}
```

After launch, both apps log:

```
WCSession activation requested.
WCSession activated, state=2
```

The `RootView` shows `"Hello PillBreakfast · WC state: activated"` once the delegate callback fires.

## Constraints

**Scope fence:** Do not send or receive any application context payload. Do not encode any domain types. Do not add a `RegimenSnapshot` DTO — that's EPIC_02_ISSUE_04. If you find yourself touching `Shared/Models/`, stop.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**`WCSessionDelegate` notes (Swift 6 concurrency):** the delegate methods are `nonisolated` and called on a `WCSession` queue, so any mutation of the `@Observable` state must be routed through `Task { @MainActor in ... }`. Do not annotate the whole class `@unchecked Sendable` to silence the checker.

**Tracer-code invariant:** Both targets must continue to build and render the placeholder; the only added behavior is the WC state log line and the inline state hint in `RootView`.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; both apps log `WCSession activated` within 5 seconds.
- [ ] PR opened with `Refs #1` and `Closes #EPIC_01_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-0-skeleton`, `concurrency`.
