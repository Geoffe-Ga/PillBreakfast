## Role

You are a senior SwiftUI engineer making the HealthKit-import onboarding flow feel like an intentional first-impression instead of a sheet that happened.

## Goal

Polish `HealthKitImportSheet` + `ConfirmComponentsView` so the first thing a user sees after install (or the first time they trigger Health import) reads as carefully designed. Use the design tokens (#158) for hero typography, hero SF Symbol, deliberate motion, and a calm step-by-step rhythm.

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issue:** #158 (design tokens).
- **SPEC sections:** §3 (HealthKit constraint — read-only import), §6.2, §9.
- **Files involved:**
  - `PillBreakfast/HealthKitImport/HealthKitImportSheet.swift` — sheet container, hero/permissions step.
  - `PillBreakfast/HealthKitImport/HealthKitImportService.swift` — no logic changes, but the visual polish may surface waiting states better.
  - `PillBreakfast/HealthKitImport/ConfirmComponentsView.swift` — confirmation rhythm, per-medication card treatment.
  - `PillBreakfast/HealthKitImport/HealthMedicationDraft.swift` — read-only; no changes.

## Output Format

A single PR containing:

- [ ] **Hero step**: large SF Symbol (`heart.text.square.fill` or `pills.fill` — monochromatic), `displayFont` headline ("Import from Health"), `footnoteFont` body explaining the read-only constraint without sounding apologetic.
- [ ] **Permissions empty state** (when no medications found): custom illustration spot using SF Symbols, `headlineFont` headline ("Nothing to import"), `footnoteFont` body with a "you can still add medications manually" CTA.
- [ ] **Confirm components rhythm**: each Health-found medication renders in an elevated card (`CornerRadius.card`, `.elevation(.raised)`) with the medication name in `medicationNameFont`, components in `footnoteFont`, the manual-confirm toggle treated as a primary action with `Motion.snappy` press feedback.
- [ ] **Progress between steps**: subtle progress dots or a header rule that communicates "step 1 of N" without dominating; `Motion.gentle` transition between import steps.
- [ ] **No new colors** — onboarding stays inside the monochromatic constraint.

## Constraints

**Scope fence:** HealthKit import surface only. **No** changes to the import service's data flow or model mapping.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** HealthKit import still produces correct `Medication` rows with manually-confirmed components.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; the import flow visibly feels deliberate.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
