## Role

You are a senior SwiftUI engineer making the iPhone Ingredients tab and Settings tab feel as finished as the rest of the surfaces.

## Goal

Apply the design tokens (#158) across `IngredientsListView` + `IngredientEditorView` + `SettingsView` so they read as one continuous polished product, not a leftover utility surface. The disclaimer at the top of Ingredients gets typographic respect; the editor form gets section rhythm; Settings rows get the same treatment as Regimen rows.

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issues:** #158 (tokens), and the ingredient autocomplete work (#155–#157 — once that lands, the search bar should also get the polish pass).
- **SPEC sections:** §5.3, §6.2, §9.
- **Files involved:**
  - `PillBreakfast/RegimenTab/IngredientsListView.swift` — disclaimer treatment, list row hierarchy, search-results visual.
  - `PillBreakfast/RegimenTab/IngredientEditorView.swift` — form section rhythm, threshold input treatment, high-risk toggle treatment.
  - `PillBreakfast/SettingsTab/SettingsView.swift` — section rhythm, row hierarchy.

## Output Format

A single PR containing:

- [ ] **Ingredients disclaimer**: lifted into a glass card with `CornerRadius.card`, `.elevation(.raised)`, `headlineFont` lead-in ("Important"), `footnoteFont` body — the disclaimer should feel earnest, not boilerplate.
- [ ] **Ingredient row**: name in `medicationNameFont`, threshold summary in `footnoteFont`, optional "High risk" badge with `CornerRadius.tight` (carrying the existing amber accent because it's a high-risk indicator — the only color exception).
- [ ] **Ingredient editor**: section headers in `headlineFont`, ceiling/interval fields in `dosageFont` with `monospacedDigit`, validation text in `footnoteFont`.
- [ ] **Settings rows**: navigation rows use `headlineFont` for the label, `footnoteFont` for the subtitle; sections use `Spacing.generous` between them.
- [ ] **Settings empty/info states**: any "no value" or "not configured" rows get the same calm typography rather than the default grey "—".
- [ ] **No new colors** — high-risk badge stays amber, everything else stays mono.

## Constraints

**Scope fence:** Ingredients + Settings only. **No** changes to seed library, autocomplete logic, or the search-miss row from #156 (this issue runs after that and assumes that landed; it just makes the search results read prettier).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Ingredient CRUD, search (post-#156), and deletion still work. Settings rows still navigate.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
