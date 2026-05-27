## Role

You are a senior iOS engineer building the import-selection sheet on top of the now-working authorization layer.

## Goal

Query `HKUserAnnotatedMedication` via `HKAnchoredObjectQuery` (one-shot for v1; future-work issue ELP_11_ISSUE_04 makes it incremental). Surface results in the import sheet with selection state per medication. Confirm button maps the chosen ones to draft `Medication`s (mapping itself is the next issue).

## Context

- **Parent epic:** #7
- **Predecessor issue(s):** #EPIC_07_ISSUE_02_NUMBER.
- **SPEC section:** `plans/SPEC.md` §3.1, §10 Phase 6.
- **Files involved:**
  - `iOSApp/HealthKitImport/HealthKitImportService.swift` — add `fetchUserAnnotatedMedications()`.
  - `iOSApp/HealthKitImport/HealthKitImportSheet.swift` — render the selection list.
  - `iOSApp/HealthKitImport/HealthMedicationDraft.swift` (new) — `Sendable` DTO mirroring the queried Health medication fields we need.
- **Prior decisions (locked):**
  - **One-shot query** for v1 (the anchored-object delta sync is future work).
  - Selection state is per-row.
  - **No automatic mapping yet.** Confirm button hands the selected drafts to the mapping step (EPIC_07_ISSUE_04).
- **State of the world:** Authorization works; the sheet shows an empty state after auth.

## Output Format

A single PR containing:

- [ ] `fetchUserAnnotatedMedications() async throws -> [HealthMedicationDraft]` returning a value-type list (never expose `HKUserAnnotatedMedication` outside the service).
- [ ] Selection list UI in `HealthKitImportSheet` with each row showing the medication name, scheduled times, and "tap to toggle import."
- [ ] Confirm button passes selected drafts forward.
- [ ] Tests: the service can be replaced by a fake returning fixture drafts; the sheet renders correctly with 0 / 1 / many results.

## Examples

```swift
public struct HealthMedicationDraft: Sendable, Hashable, Identifiable {
    public let id: UUID  // PillBreakfast-side UUID
    public let healthKitConceptID: String
    public let displayName: String
    public let scheduledTimes: [DateComponents]  // hour + minute only
}
```

## Constraints

**Scope fence:** No mapping to `Medication` — EPIC_07_ISSUE_04. No dedupe — EPIC_07_ISSUE_05.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Sheet now shows real Health medications; Confirm is a no-op (or routes to a placeholder).

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #7` and `Closes #EPIC_07_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-6-healthkit`.
