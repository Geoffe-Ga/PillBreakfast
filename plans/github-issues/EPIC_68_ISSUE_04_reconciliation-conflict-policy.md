## Role

You are a senior Swift 6 / SwiftData engineer hardening the coexistence of the WatchConnectivity and CloudKit channels: proving the overlap is idempotent, defining the conflict policy for safety-critical fields, and handling the iCloud failure modes.

## Goal

Assert and lock in that a dose arriving via both WC and CloudKit produces exactly one row (idempotent upsert-by-`DoseEvent.id`), that regimen convergence stays archive-never-delete, and that ingredient-ceiling conflicts resolve safely. Add graceful handling for account-switch, no-account, restricted, and quota-exceeded states.

## Context

- **Parent epic:** #68
- **Predecessors:** ISSUE_01 (schema), ISSUE_02 (conditional config), ISSUE_03 (toggle). Cloud delivery now exists when enabled.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` §5.3 (authority model / no double-write loop), §5.4 (conflict resolution), §8 (failure modes), §11 (ceiling LWW open question).
- **Files involved:**
  - `Shared/Sync/DoseEventBatchDTO.swift` + the dose merger (`DoseEventBatchMerger`) — already upsert-by-id; extend tests to cover the "same id via WC and via CloudKit" case (idempotent no-op except a newer `notes`).
  - `Shared/Sync/RegimenSnapshot.swift` — `apply(to:)` is validate-before-mutate + archive-never-delete; assert a stale-device deletion can't destroy history after convergence.
  - The ingredient-ceiling read path the watch uses (`violationsIfTaken` derivation) — confirm the watch always re-derives from the currently-synced ceilings; consider a "stricter-wins" custom reconciliation for the ceiling field if feasible (else field-level LWW, documented).
  - `Shared/Persistence/PersistenceController.swift` — surface iCloud account/availability state changes for the failure-mode handling.
- **Prior decisions (locked):**
  - The watch is **not** a CloudKit peer, so there is no risk of WC and CloudKit both writing the same row on the watch. On the phone, the same dose from both channels is reconciled by the existing idempotent upsert-by-id.
  - `DoseEvent` is append-mostly (immutable except `notes`); cross-device dose conflicts are near-impossible by construction.
  - Regimen edits resolve last-writer-wins at the record/field level; archive-never-delete prevents stale-device deletion from destroying history.
  - Ingredient ceilings are the highest-consequence field: recommend "stricter wins" if feasible; the watch always re-derives violations from the synced ceilings on next open.
  - Account switch must **never** silently merge two users' data.

## Output Format

A single PR containing:

- [ ] Idempotency assertions/tests: same `DoseEvent.id` via WC and via CloudKit → exactly one row; a changed `notes` follows the existing newer-note-wins rule.
- [ ] Regimen convergence: archive-never-delete verified post-convergence; concurrent edits resolve last-writer-wins without history loss.
- [ ] Ingredient-ceiling conflict policy implemented (stricter-wins if feasible, else documented field-LWW) with the watch re-deriving violations from synced ceilings.
- [ ] Failure-mode handling: no-account / restricted → local-only; account-switch → re-scope, never silent-merge, surface a note; quota-exceeded → clear error, local store keeps working.
- [ ] Tests for each failure mode (headless / no live iCloud where possible).

## Examples

```swift
// WC delivers dose X; CloudKit later delivers the same dose X.
merger.merge([doseX], into: context)   // inserts
merger.merge([doseX], into: context)   // idempotent no-op (except a newer note)
#expect(try context.fetchCount(FetchDescriptor<DoseEvent>(predicate: #Predicate { $0.id == doseX.id })) == 1)
```

## Constraints

**Scope fence:** Reconciliation, conflict policy, and failure-mode handling only. **No** new Settings UI (beyond a status note), **no** entitlement changes, **no** watch-as-peer, **no** caregiver/sharing.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The watch continues to receive the regimen and emit doses over WC unchanged, including phone-off. A dose seen via both channels is one row. No-iCloud devices run fully local. Account switch never merges two users.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #68`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `edges`, `concurrency`
