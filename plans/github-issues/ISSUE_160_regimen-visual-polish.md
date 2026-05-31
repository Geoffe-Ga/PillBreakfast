## Role

You are a senior SwiftUI engineer making the iPhone Regimen tab — `RegimenListView`, `MedicationFormView`, schedule row editor, PRN form section — look like a finished consumer health product instead of a default `List` + `Form`.

## Goal

Polish the iPhone Regimen surface so a user opening it the first time reads it as deliberate, calm, and trustworthy. Apply the design tokens (#158) for typography hierarchy and elevation; replace the bare `List` / `Form` aesthetic with glass cards where it makes sense; refine the empty state, the medication row visuals, and the form layout cadence.

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issue:** #158 (design token expansion).
- **SPEC sections:** §6.2 (iPhone setup), §9 (visual design).
- **Files involved:**
  - `PillBreakfast/RegimenTab/RegimenListView.swift` — list visual hierarchy, medication row treatment, empty state polish.
  - `PillBreakfast/RegimenTab/RegimenTabHostView.swift` — navigation bar treatment.
  - `PillBreakfast/RegimenTab/MedicationFormView.swift`, `AddMedicationView.swift`, `EditMedicationView.swift` — form section rhythm, sticky save action, validation copy treatment.
  - `PillBreakfast/RegimenTab/ScheduleRowEditor.swift` — schedule row visual hierarchy.
  - `PillBreakfast/RegimenTab/PRNFormSection.swift` — PRN form rhythm.

## Output Format

A single PR containing:

- [ ] **Empty state** on `RegimenListView`: `ContentUnavailableView` with a custom SF Symbol hero, `displayFont` title, `footnoteFont` body — feels intentional, not the default text-only blank.
- [ ] **Medication row** on `RegimenListView`: name in `medicationNameFont`, schedule summary in `footnoteFont`, optional kind badge (Maintenance / PRN) with `CornerRadius.tight`, `.elevation(.raised)` on the row card. High-risk meds keep their amber accent only on the high-risk indicator — no decoration drift.
- [ ] **Navigation bar**: large title style, `.toolbarTitleDisplayMode(.large)` on the top-level list, `.inline` on push destinations.
- [ ] **Form section pacing** on `MedicationFormView`: `Spacing.generous` between major sections, `Spacing.standard` within sections; section headers use `headlineFont`; validation copy renders in `footnoteFont` with `.secondary` foreground.
- [ ] **Save action treatment**: primary action in the toolbar uses `Motion.snappy` press feedback, `CornerRadius.standard` if the button shape can be customised in the toolbar slot.
- [ ] **No new colors** anywhere — high-risk indicator stays amber, everything else stays monochrome glass.

## Constraints

**Scope fence:** Regimen tab only. **No** changes to the watch app, History, Ingredients, Settings, or onboarding (those are their own issues).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Adding, editing, archiving, and deleting medications still works end-to-end on the simulator.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; the Regimen tab visibly reads as polished.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
