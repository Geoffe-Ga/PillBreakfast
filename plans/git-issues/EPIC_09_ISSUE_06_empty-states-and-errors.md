## Role

You are a senior SwiftUI engineer auditing and polishing the empty / error states across PillBreakfast.

## Goal

Audit every screen on both targets for empty states and error paths. Replace silent `try?`s with user-readable error views. Add empty states for: zero medications on Regimen tab, zero PRN products on watch PRN list, zero history on History tab, zero pending doses on watch "all caught up." Error states for: WatchConnectivity unreachable, HealthKit denied, SwiftData save failure.

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_05_NUMBER.
- **SPEC section:** `plans/SPEC.md` §10 Phase 8 ("Final polish: empty states, error handling, accessibility audit"). Also see the `user-facing-error-messages` skill if available.
- **Files involved:** every primary view. Audit first; PR includes a list of touched files.
- **Prior decisions (locked):**
  - **Replace `try?` patterns that swallow errors** with explicit error views or logged-and-recovered paths.
  - **Empty states use the Liquid Glass design system.**
- **State of the world:** End-to-end functionality works; many screens render blank or crash on edge cases.

## Output Format

A single PR containing:

- [ ] Audit checklist in the PR body listing every screen touched.
- [ ] Empty state views for the listed surfaces.
- [ ] Error state views.
- [ ] Replacement of swallowed errors with explicit handling.
- [ ] Tests for at least one error state per surface (e.g., HealthKit-denied path on iPhone import sheet).

## Constraints

**Scope fence:** No new features. Accessibility audit — EPIC_09_ISSUE_07.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No regression; every screen now handles emptiness and errors gracefully.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_06_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-8-history-export`.
