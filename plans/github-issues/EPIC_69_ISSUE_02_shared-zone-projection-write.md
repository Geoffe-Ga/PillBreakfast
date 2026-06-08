## Role

You are a senior CloudKit / Swift 6 engineer creating the dedicated shared record zone and writing the read-only projection records into it from the patient's device, built on the #68 CloudKit foundation.

## Goal

Create a custom CloudKit record zone (required for `CKShare` — the default zone can't be shared) and write/refresh `CaregiverRegimenProjection` / `CaregiverAdherenceProjection` records into it from the patient device. The patient's **real** store stays in the private (unshared) zone; only the projection is written to the shared zone. No invite or share is created yet.

## Context

- **Parent epic:** #69
- **Predecessors:** ISSUE_01 (projection types + #68 prerequisite confirmed).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §5.1 (recommended architecture), §5.2 (projection, not raw zone), §5.5 (concurrency).
- **Files involved:**
  - The CloudKit container from #68 (`iCloud.com.creekmasons.pillbreakfast`) — reuse it; add a custom record zone for shareable projections.
  - The projection builders from ISSUE_01.
  - New caregiver-sync code (e.g. `Shared/Caregiver/CaregiverProjectionStore.swift`), MainActor-collect → async CloudKit write.
- **Prior decisions (locked):**
  - A **custom zone** is required for `CKShare`; the default zone can't be shared.
  - Share a projection, not the raw model zone — the caregiver app literally cannot request fields not in the projection record.
  - The patient's real store stays in the private unshared zone; sharing never exposes the full graph.
  - Projection records are built from `Sendable` DTOs; CloudKit operations are async; no `@unchecked Sendable`.
  - Off by default — gated behind consent (added in ISSUE_03) before anything is actually written in a user-visible flow.

## Output Format

A single PR containing:

- [ ] Custom shareable record zone creation in the #68 container.
- [ ] `CaregiverProjectionStore` (or equivalent): write/refresh projection records from the patient device; async CloudKit ops off main.
- [ ] Idempotent refresh (re-writing a projection updates in place, doesn't duplicate).
- [ ] Tests (gated for headless CI; CloudKit-dependent paths skip without an account, projection-build/serialization logic unit-tested without a live zone):
  - projection records serialize from the ISSUE_01 types with no notes field present.
  - refresh is idempotent (one record per logical projection).
  - the real store records are never written to the shared zone (only projections).

## Examples

```swift
// patient device
let zone = CKRecordZone(zoneName: "CaregiverShare")
// write only projection records into `zone`; the real Medication/DoseEvent stay in the private default-zone store
```

## Constraints

**Scope fence:** Shared zone + projection write only. **No** `CKShare`/invite (ISSUE_04), **no** consent UI (ISSUE_03), **no** viewer, **no** revocation. Never write raw model records to the shared zone.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; with no consent configured nothing is shared. The zone + projection-write machinery exists and is tested; the patient's real store is untouched and the watch is unaffected.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `core`, `concurrency`
