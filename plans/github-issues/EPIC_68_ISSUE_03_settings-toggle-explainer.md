## Role

You are a senior SwiftUI engineer adding the iCloud Sync control surface to the iPhone Settings tab: an opt-in toggle, live status, and a one-screen explainer that the user's medical data will live in their private iCloud.

## Goal

Settings (iPhone Tab 3, SPEC §6.3) gains an iCloud Sync toggle bound to the opt-in flag from ISSUE_02, a status line reflecting sync state ("Synced just now" / "Waiting for iCloud" / "iCloud unavailable — using this device only"), and a first-enable explainer screen. Monochrome Liquid Glass, no accent color. No watch-facing UI.

## Context

- **Parent epic:** #68
- **Predecessors:** ISSUE_02 (the opt-in flag + conditional container config exist; this surfaces them).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` §7 (UX), §8 (status states / no-account / restricted).
- **Files involved:**
  - The iPhone Settings tab view (SPEC §6.3 — locate the existing Settings surface in `PillBreakfast/`).
  - The opt-in flag store from ISSUE_02 (`UserPreferences`/equivalent) the toggle binds to.
  - `Shared/Persistence/PersistenceController.swift` — the toggle drives the cloud-vs-local choice it reads at build time; surface the iCloud-availability state for the status line.
- **Prior decisions (locked):**
  - **Opt-in, not default-on**, with an explicit explainer that data goes to the user's **private** iCloud (encrypted, Apple-account-scoped, not shared).
  - The user must be able to turn it off and keep using the app locally (no data loss — guaranteed by the same-URL config in ISSUE_02).
  - Monochrome Liquid Glass; no accent color (amber stays reserved for high-risk press-and-hold on the watch). No watch UI.
  - Status must honestly reflect no-account / restricted as "iCloud unavailable — using this device only."

## Output Format

A single PR containing:

- [ ] Settings iCloud Sync `Toggle` bound to the opt-in flag.
- [ ] Status line driven by sync/availability state.
- [ ] First-enable explainer screen (private iCloud, encrypted, not shared; can be turned off anytime).
- [ ] Tests:
  - toggling on flips the flag (and, on next container build, selects the cloud config — assert the flag, not live iCloud).
  - no-account state renders "iCloud unavailable — using this device only" and the toggle reflects the unavailable state.
  - explainer is shown on first enable, not on subsequent toggles.

## Examples

```swift
Toggle("iCloud Sync", isOn: $prefs.iCloudSyncEnabled)
Text(syncStatus.displayText)   // "Synced just now" / "Waiting for iCloud" / "iCloud unavailable — using this device only"
```

## Constraints

**Scope fence:** Settings toggle + status + explainer only. **No** reconciliation/conflict logic (ISSUE_04), **no** entitlement/config changes (done in ISSUE_02), **no** watch UI, **no** accent color.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** With the toggle off (default), the app behaves exactly as today. The toggle and explainer render in Settings; flipping the flag is wired to the ISSUE_02 config selection. The watch is untouched.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #68`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`
