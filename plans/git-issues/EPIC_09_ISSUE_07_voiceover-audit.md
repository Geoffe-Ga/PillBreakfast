## Role

You are a senior accessibility engineer running a full VoiceOver audit across iPhone and watch.

## Goal

Every interactive element on both targets must have a meaningful `accessibilityLabel`, appropriate traits, and be navigable in a logical order via VoiceOver. Tap-through queue: VoiceOver speaks the medication name, dosage, and the gesture required. Complication and widget: VoiceOver speaks the pending count or "all caught up."

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_06_NUMBER.
- **SPEC section:** `plans/SPEC.md` §10 Phase 8 ("accessibility audit (VoiceOver labels on every interactive element)").
- **Files involved:** every interactive view.
- **Prior decisions (locked):**
  - **WCAG 2.1 AA compliance** for color contrast (the monochromatic baseline already satisfies this for text; verify on the amber accent).
  - Press-and-hold gesture surfaces a `.accessibilityAction(named: "Confirm dose")` adapter so VoiceOver users can complete it with a double-tap.
- **State of the world:** Empty / error states landed. Many screens have implicit accessibility labels but not curated ones.

## Output Format

A single PR containing:

- [ ] Audit list in PR body: every interactive view.
- [ ] Explicit `accessibilityLabel`, `accessibilityValue`, `accessibilityTraits` on each.
- [ ] Tap-through high-risk: alternate accessibility action so VoiceOver users can confirm without a literal press-and-hold.
- [ ] Complications + Smart Stack widget: meaningful spoken labels.
- [ ] Manual VoiceOver walkthrough recorded in the PR (video link or screen recording).

## Constraints

**Scope fence:** No new features. No new visuals.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End of EPIC 09. Phase 8 gate passes; v1 feature set is complete.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; VoiceOver walkthrough completes.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_07_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-8-history-export`, `a11y`.
