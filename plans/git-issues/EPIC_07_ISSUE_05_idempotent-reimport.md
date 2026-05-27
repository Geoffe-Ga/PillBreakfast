## Role

You are a senior Swift engineer closing the EPIC 07 loop with idempotent re-import.

## Goal

Make the import flow idempotent: running it again with the same Health authorization does not duplicate medications. Dedupe is keyed on `Medication.healthKitConceptID`. Existing medications retain user edits; the importer does not touch them.

## Context

- **Parent epic:** #7
- **Predecessor issue(s):** #EPIC_07_ISSUE_04_NUMBER.
- **SPEC section:** `plans/SPEC.md` §10 Phase 6 gate ("Wipe app, set up Lithium in Apple Health first, then install PillBreakfast. Import flow pulls it in without re-typing.").
- **Files updated:**
  - `iOSApp/HealthKitImport/HealthKitImportSheet.swift` — flag existing entries.
  - `iOSApp/HealthKitImport/HealthMedicationMapper.swift` — early-out on dedupe.
- **Prior decisions (locked):**
  - **No merge semantics.** A Health medication that already exists locally is shown as "Already imported" and unselectable. No updates to its schedule from Health.
  - Dedupe by `healthKitConceptID`, not by display name.
- **State of the world:** Import works; running it twice creates duplicates.

## Output Format

A single PR containing:

- [ ] Pre-fetch existing `healthKitConceptID`s; mark already-imported drafts as `.disabled`.
- [ ] Mapper skips drafts whose `healthKitConceptID` is already present.
- [ ] Tests: re-importing the same fixture inserts zero new medications.
- [ ] Manual checklist: set up Lithium in Health, import once, run import again, observe Lithium marked "Already imported."

## Constraints

**Scope fence:** No merge / update semantics.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End of EPIC 07; the Phase 6 gate test case passes.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; Phase 6 manual checklist completes.
- [ ] PR opened with `Refs #7` and `Closes #EPIC_07_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `edges`, `phase-6-healthkit`.
