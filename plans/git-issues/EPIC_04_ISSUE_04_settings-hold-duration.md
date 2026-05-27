## Role

You are a senior Swift engineer adding the first real entry to the iPhone Settings tab. You understand how to persist app-wide preferences in SwiftData (or App Group `UserDefaults`) and sync them to the watch.

## Goal

Add a Settings tab entry on iPhone for "High-risk hold duration" with a slider or stepper between 0.3s and 2.0s in 0.1s increments (default 0.5s). Persist the value, sync it to the watch via the existing `RegimenSnapshot` channel (extend the snapshot's top level with a `preferences` field), and consume it on the watch's `HighRiskConfirmButton`.

## Context

- **Parent epic:** #4
- **Predecessor issue(s):** #EPIC_04_ISSUE_02_NUMBER (the gesture must accept a configurable duration).
- **SPEC section:** `plans/SPEC.md` §6.3 (Settings — "High-risk confirmation gesture (press duration tweakable)").
- **Files involved:**
  - `Shared/Preferences/UserPreferences.swift` (new) — a `Codable, Sendable` struct with `highRiskHoldDurationSeconds: TimeInterval`.
  - `Shared/Sync/RegimenSnapshot.swift` — add `preferences: UserPreferences` to the snapshot.
  - `iOSApp/SettingsTab/SettingsView.swift` — first real entry.
  - `WatchApp Watch App/TapThroughQueue/HighRiskConfirmButton.swift` — read the duration from the synced preferences.
- **Prior decisions (locked):**
  - Preferences live in **App Group `UserDefaults`**, not SwiftData. They're a single small struct; SwiftData is overkill.
  - Range and default: 0.3s - 2.0s, default 0.5s. SPEC §2.1 cites "0.5s" as the example.
  - Bumping the schemaVersion on `RegimenSnapshot` is required since the wire format changes; if the watch receives a snapshot with `schemaVersion == 1` (no preferences), default to 0.5s.
- **State of the world:** EPIC_04_ISSUE_03 is merged. The watch uses a hard-coded 0.5s.

## Output Format

A single PR containing:

- [ ] `UserPreferences` struct and a `UserPreferencesStore` (App Group `UserDefaults`-backed) on iPhone.
- [ ] `SettingsView` with the new entry plus a "Reset to defaults" button.
- [ ] `RegimenSnapshot.schemaVersion == 2`; iPhone-side snapshot builder fills `preferences`; watch-side apply path stores them; default-on-decode-old-version is `UserPreferences(highRiskHoldDurationSeconds: 0.5)`.
- [ ] `HighRiskConfirmButton` consumes the preference via an `@Environment(UserPreferencesStore.self)` or equivalent.
- [ ] Tests: encoding/decoding old + new snapshot versions; range clamping (anything outside 0.3-2.0 is clamped); UI smoke test for the slider.

## Examples

```swift
public struct UserPreferences: Codable, Sendable, Hashable {
    public static let defaultHoldDuration: TimeInterval = 0.5
    public static let holdDurationRange: ClosedRange<TimeInterval> = 0.3...2.0

    public var highRiskHoldDurationSeconds: TimeInterval

    public init(highRiskHoldDurationSeconds: TimeInterval = Self.defaultHoldDuration) {
        self.highRiskHoldDurationSeconds = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
    }
}
```

## Constraints

**Scope fence:** Do not add other settings entries. Do not surface a "default snooze offset" (EPIC 06 issue). Do not surface a HealthKit re-auth button (EPIC 07).

**Schema version bump is required.** Receiving an old snapshot must not crash; default to 0.5s.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets build and run; changing the slider on iPhone causes the watch's hold duration to change on the next snapshot push.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #4` and `Closes #EPIC_04_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-3-high-risk`.
