## Role

You are a senior SwiftData / Swift 6 engineer wiring the CloudKit container behind an availability + opt-in gate, so the store is CloudKit-backed when enabled and falls back to a byte-identical local-only store otherwise.

## Goal

Add the iCloud/CloudKit entitlement and container, and make `PersistenceController` build either a CloudKit-backed `ModelConfiguration(cloudKitDatabase: .private(...))` or a local-only `ModelConfiguration(url:)` — on the **same** App-Group store URL — chosen by iCloud availability and a user opt-in flag. Default off. When off (or no account), behavior is identical to today.

## Context

- **Parent epic:** #68
- **Predecessors:** ISSUE_01 (schema is CloudKit-compatible + versioned migration).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` §5.1 (container configuration + gating), §5.5 (concurrency), §8 (no-account / restricted fallbacks).
- **Files involved:**
  - `Shared/Persistence/PersistenceController.swift` — `@MainActor`; today builds `ModelConfiguration(url: appGroupStoreURL)` with **no** `cloudKitDatabase:`. Add the conditional. `appGroupIdentifier = "group.com.creekmasons.pillbreakfast"`; CloudKit container `iCloud.com.creekmasons.pillbreakfast`. The local and cloud configs are schema-identical (same `Schema`), so toggling cloud on later mirrors existing local data up; off leaves it intact.
  - iOS target entitlements/capabilities — iCloud → CloudKit + the container; `remote-notification` background mode (per CLAUDE.md capabilities) for the silent pushes `NSPersistentCloudKitContainer` needs.
  - A persisted opt-in flag (e.g. `UserPreferences`/equivalent) read at container-build time.
- **Prior decisions (locked):**
  - Same store URL for both configs — toggling cloud on/off must not lose data.
  - CloudKit conditional on iCloud availability **and** explicit opt-in; default off.
  - No new isolation surface — `PersistenceController` stays `@MainActor`; `NSPersistentCloudKitContainer` operates under SwiftData's hood. **No `@unchecked Sendable`.**
  - The watch is **not** a CloudKit peer — this config change is iPhone/iPad-side; the watch keeps its WC-only path.

## Output Format

A single PR containing:

- [ ] iCloud/CloudKit entitlement + container id + `remote-notification` mode on the iOS target.
- [ ] `PersistenceController` builds CloudKit-backed vs. local-only `ModelConfiguration` on the same URL, gated on availability + opt-in flag; default local-only.
- [ ] iCloud-availability probe (no account / restricted → local-only).
- [ ] Tests (headless / no live iCloud account):
  - opt-in off → local-only config; full CRUD works (this is the CI-safe path).
  - no-account environment → local-only config regardless of the flag.
  - the store URL is identical across both configs (toggling does not point at a new store).

## Examples

```swift
let configuration: ModelConfiguration = shouldUseCloud
  ? ModelConfiguration(url: Self.appGroupStoreURL,
                       cloudKitDatabase: .private("iCloud.com.creekmasons.pillbreakfast"))
  : ModelConfiguration(url: Self.appGroupStoreURL)   // identical URL; no data loss on toggle
```

## Constraints

**Scope fence:** Entitlements + conditional container config only. **No** Settings UI yet (ISSUE_03 reads the flag this issue defines), **no** reconciliation hardening (ISSUE_04), **no** watch changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** With opt-in off (the default), both apps build and run on the paired simulator and behave exactly as today on the local store. The watch's WC sync is untouched. CI without an iCloud account passes via the local-only path.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #68`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
