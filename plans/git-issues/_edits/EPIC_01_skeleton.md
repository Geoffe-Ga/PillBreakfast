# EPIC 01 — Phase 0: Paired iOS + watchOS Skeleton

## Epic Summary

Stand up the paired iOS + watchOS Xcode project so every subsequent epic has a concrete codebase to land in. Both targets build, launch on the paired simulator pair, share a SwiftData container via App Group, and successfully activate a `WCSession` handshake that logs to the console. Implements SPEC §10 Phase 0 (lines 397-408).

This is the skeleton-of-skeletons: nothing else can be picked up until it lands. It deliberately ships zero product behavior — just the surface area every later epic will plug into.

## Scope

**In scope:**

- New Xcode project from the "Watch-only App with iOS Companion" template (Xcode 17), Swift 6 strict concurrency turned on for both targets.
- Bundle identifiers, App Group entitlement, and capabilities (HealthKit on iOS only; Background Modes for Remote Notifications + Background Fetch on both).
- A `Shared/` folder wired into both targets per SPEC §13's layout (note the actual directory is `plans/` not `plan/`).
- A `PersistenceController` that opens a SwiftData `ModelContainer` in the App Group container URL, accessible from both targets. The schema is empty for now — `@Model` classes arrive in EPIC 02.
- A `WatchConnectivityCoordinator` actor on each side that calls `WCSession.default.activate()` in `applicationDidFinishLaunching` (or scene equivalent), implements `WCSessionDelegate`, and logs activation state.
- A placeholder root SwiftUI view on each target showing "Hello PillBreakfast" plus the current `WCSession.activationState`.
- A repo `README.md` section ("Build / Test / Run") replacing CLAUDE.md's "no commands yet" stub: Xcode scheme names, `xcodebuild test` invocations, paired-simulator boot command.
- A unit test target per platform with a single smoke test (`testHelloWorldViewRenders`) so `xcodebuild test` returns nonzero on regression.

**Out of scope:**

- Any `@Model` classes (EPIC 02).
- Any real WatchConnectivity payload (EPIC 02 sends the first regimen).
- Any Liquid Glass styling (EPIC 04).
- Notifications, HealthKit calls, complications (later epics).

## Success Criteria

The epic is done when:

- [ ] Both iOS and watchOS schemes build cleanly with Swift 6 strict concurrency and zero warnings.
- [ ] `xcodebuild test` passes for both schemes against the paired simulator pair.
- [ ] Launching both apps on the simulator pair logs `WCSession activated, state=.activated` on each side within 5 seconds.
- [ ] The App Group is present and a SwiftData container opens against its URL on both targets (verified by a smoke test that writes a sentinel UserDefaults key into the suite).
- [ ] `pre-commit run --all-files` is clean — `scripts/swiftformat_lint.sh` reports no diffs.
- [ ] CLAUDE.md's "Build / Test / Run" section is updated with the real scheme names and commands.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #12 — Skeleton: Create paired Xcode project, App Group, capabilities, and placeholder views (EPIC_01_ISSUE_01).
- [ ] #13 — Wire empty SwiftData `ModelContainer` against the App Group container URL (EPIC_01_ISSUE_02).
- [ ] #14 — Stub `WatchConnectivityCoordinator` actor on both targets with activation logging (EPIC_01_ISSUE_03).
- [ ] #15 — Update build / test / run documentation in `CLAUDE.md` and add a top-level `README.md` (EPIC_01_ISSUE_04).

## Sequencing Notes

- **Blocks:** EPIC 02 through EPIC 11. Nothing in the rest of the decomposition can start until the project file exists.
- **Unblocks:** All later epics.
- **Parallel-safe:** None — this is the foundation.

## SPEC Reference

`plans/SPEC.md` §10 Phase 0 (lines 397-408); §4 (Tech Stack); §13 (Recommended layout).

## Labels

`epic`, `spec-decomposition`, `phase-0-skeleton`, `tracer-code`.
