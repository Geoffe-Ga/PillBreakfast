## Role

You are a senior Swift engineer adding a second user preference and threading it through the snooze flow.

## Goal

Add a "Default snooze offset" entry to the iPhone Settings tab (15 / 30 / 45 / 60 / 90 minutes, default 30). Promote it into `UserPreferences` (which already exists from EPIC_04_ISSUE_04). The watch's `SnoozeView` uses this as the initial picker position.

## Context

- **Parent epic:** #6
- **Predecessor issue(s):** #EPIC_06_ISSUE_04_NUMBER.
- **SPEC section:** `plans/SPEC.md` §6.3 ("Default snooze offset for the snooze picker").
- **Files involved:**
  - `Shared/Preferences/UserPreferences.swift` — add `defaultSnoozeOffsetMinutes: Int` (default 30).
  - `Shared/Sync/RegimenSnapshot.swift` — bump schemaVersion to 3; default-on-old-decode is 30.
  - `iOSApp/SettingsTab/SettingsView.swift` — add a Picker.
  - `WatchApp Watch App/SnoozeView/SnoozeView.swift` — read the preference for the initial picker position.
- **State of the world:** Snooze flow + 3-snooze warning are complete.

## Output Format

A single PR containing:

- [ ] `UserPreferences.defaultSnoozeOffsetMinutes` field with allowed values [15, 30, 45, 60, 90].
- [ ] Snapshot schemaVersion bump to 3 with backward decoding.
- [ ] Settings UI Picker.
- [ ] `SnoozeView` consumes the preference.
- [ ] Tests: pref defaulting on old snapshot version; preference round-trips through snapshot sync.

## Examples

```swift
public struct UserPreferences: Codable, Sendable, Hashable {
    public static let allowedSnoozeOffsets: [Int] = [15, 30, 45, 60, 90]
    public static let defaultSnoozeOffsetMinutes: Int = 30
    public static let defaultHoldDuration: TimeInterval = 0.5
    public static let holdDurationRange: ClosedRange<TimeInterval> = 0.3...2.0

    public var highRiskHoldDurationSeconds: TimeInterval
    public var defaultSnoozeOffsetMinutes: Int

    public init(
        highRiskHoldDurationSeconds: TimeInterval = Self.defaultHoldDuration,
        defaultSnoozeOffsetMinutes: Int = Self.defaultSnoozeOffsetMinutes
    ) {
        self.highRiskHoldDurationSeconds = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
        self.defaultSnoozeOffsetMinutes = Self.allowedSnoozeOffsets.contains(defaultSnoozeOffsetMinutes) ? defaultSnoozeOffsetMinutes : Self.defaultSnoozeOffsetMinutes
    }
}
```

## Constraints

**Scope fence:** Settings entry only. No watch UI for editing this preference (watch never edits regimen / settings).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End of EPIC 06. Snooze works end-to-end with user-configurable default offset.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #6` and `Closes #EPIC_06_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-5-snooze`.
