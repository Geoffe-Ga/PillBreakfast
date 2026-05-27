## Role

You are a senior iOS engineer producing the screenshots and marketing copy for the TestFlight / App Store listing.

## Goal

Capture screenshots at all required device sizes (iPhone 17, Apple Watch Series 11 46mm) showing PillBreakfast's flagship surfaces with **anonymized** but realistic regimen data. Write short and full descriptions, keywords, and "what's new" copy.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_02_NUMBER.
- **SPEC section:** §10 Phase 9.
- **Files involved:** `Submission/screenshots/`, `Submission/marketing-copy.md`.
- **Prior decisions (locked):**
  - **Anonymize.** Replace Lithium with "Med A" or similar in screenshots; the App Store does not need to see anyone's real prescription.
  - Highlight: tap-through, press-and-hold ring, ingredient-aware PRN safety warning, PDF export preview.
- **State of the world:** Icons in place.

## Output Format

A single PR containing:

- [ ] Screenshots at all required sizes.
- [ ] `marketing-copy.md` with short description (170 chars), full description, 100-char keywords, "what's new."
- [ ] Anonymization audit in PR body.

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No code change.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
