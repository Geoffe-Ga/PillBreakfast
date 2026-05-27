## Role

You are a senior iOS engineer wiring the HealthKit-import surface. You understand HealthKit usage descriptions (`Info.plist`) and the deliberate iOS-only file boundary.

## Goal

Add an "Import from Apple Health" entry to the iPhone Regimen tab toolbar (next to `+`) that opens a stub `HealthKitImportSheet`. Configure the HealthKit capability and add the required `Info.plist` usage descriptions. The watch target must continue to build with zero HealthKit Medications symbols visible.

## Context

- **Parent epic:** #7
- **Predecessor issue(s):** #EPIC_06_ISSUE_05_NUMBER (or any later-epic merge that does not regress EPIC 02 — EPIC 07 only depends on EPIC 02 for the data model, but file last so it lands on a stable base).
- **SPEC section:** `plans/SPEC.md` §3 (the entire HealthKit constraint discussion), §6.1 ("Import from Apple Health" flow step), §10 Phase 6.
- **Files involved (new):**
  - `iOSApp/HealthKitImport/HealthKitImportSheet.swift` — the stub.
  - `iOSApp/HealthKitImport/HealthKitImportService.swift` — stub actor; real authorization in EPIC_07_ISSUE_02.
- **Files updated:**
  - `iOSApp/RegimenTab/RegimenListView.swift` — toolbar entry.
  - `PillBreakfast.entitlements` (iOS only) — HealthKit capability.
  - `iOSApp/Info.plist` — `NSHealthShareUsageDescription` ("PillBreakfast reads your medications from Apple Health to make setup faster. PillBreakfast never writes to Apple Health.").
- **Prior decisions (locked):**
  - **iOS-only file boundary.** `HealthKitImport/` is in the iOS target only; no shared files import `HealthKit`'s medication symbols.
  - **Usage description is honest.** "Reads only. Never writes."
- **State of the world:** Earlier epics complete. There is no HealthKit code anywhere yet.

## Output Format

A single PR containing:

- [ ] Toolbar "Import from Apple Health" entry on Regimen tab.
- [ ] Stub sheet that opens, shows "Import flow coming next issue," and dismisses.
- [ ] Capability + usage description configured.
- [ ] Watch target compiles with no HealthKit Medications symbols present (verify by `grep` in CI or by a target-membership audit in the PR review).

## Constraints

**Scope fence:** No authorization code — EPIC_07_ISSUE_02. No querying — EPIC_07_ISSUE_03. No mapping — EPIC_07_ISSUE_04.

**Watch never imports HealthKit Medications.** SPEC §3 + CLAUDE.md. The watch target must not include any HealthKit-Medications-touching file.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** New toolbar entry opens a stub sheet; otherwise unchanged.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #7` and `Closes #EPIC_07_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-6-healthkit`.
