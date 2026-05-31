## Role

You are a senior accessibility-conscious SwiftUI engineer auditing every surface for Dynamic Type clipping, text overlap, and tap-target degradation across iPhone + watch.

## Goal

Fix the layout fail-states Geoff explicitly called out: clipping, overlap, awkward spacing — especially at AX1–AX5 Dynamic Type sizes. Touch every surface in a systematic pass: anything that breaks at the largest accessibility size gets `.minimumScaleFactor`, `Layout` reflow, `ViewThatFits`, or wrapping fixes. Watch surfaces also get the same audit at the largest watchOS text scale.

## Context

- **Parent epic:** #10 (Phase 9 — Hardening & TestFlight Submission).
- **Predecessor issue:** #158 (tokens). Issues #159–#163 may or may not have landed by the time this runs; the audit covers whatever's in `main` at tick time.
- **SPEC sections:** §9 (visual), accessibility guidance from CLAUDE.md.
- **Files involved:** every screen — this is a sweep. Expect changes to most files under `PillBreakfast/HistoryTab/`, `PillBreakfast/RegimenTab/`, `PillBreakfast/SettingsTab/`, `PillBreakfast Watch App Watch App/TapThroughQueue/`, `…/PRNSection/`, `…/SnoozeView/`, `…/RootView/`.

### Audit checklist (apply to each surface)

- Run the simulator at the largest Dynamic Type size (`Accessibility → Display & Text Size → Larger Text → AX5`) and at the largest watchOS text scale. Note any:
  - **Clipping** (text truncated mid-word, button labels cut off, navigation titles shortened to "…").
  - **Overlap** (two text views touching, button overlapping its container, sheet content crashing into the dismiss area).
  - **Vanished UI** (a control that disappears off-screen at AX5 because of fixed-frame thinking).
- Fix by, in priority order:
  1. Allowing the layout to grow vertically (`Layout` reflow, `VStack` over `HStack` at large sizes).
  2. `ViewThatFits` to pick a compact alternative when the rich layout doesn't fit.
  3. `.minimumScaleFactor(0.8)` as a **last** resort — never below 0.8, and never for safety-critical copy (dose names, threshold numbers, high-risk warnings).
- **Never use `.lineLimit(1)` to "fix" overflow** on user-supplied medication names or dosage figures — those have to wrap, not truncate.

## Output Format

A single PR containing:

- [ ] Audit notes summarising every breakage found, fix applied, and per-surface verification (small inline comment in the PR body is enough — doesn't need to be a doc).
- [ ] No surface clips, overlaps, or vanishes at AX5 on iPhone or at the largest watch text scale.
- [ ] No new `.lineLimit(1)` shortcuts on safety copy.
- [ ] Any newly-introduced `ViewThatFits` branches have a short inline comment naming the breakpoint they're solving.

## Constraints

**Scope fence:** Layout fixes only — **no** redesigns, **no** moving features around. If a surface genuinely needs a redesign to handle AX5 (e.g., the tap-through hero card at AX5 on watch), file a follow-up issue instead of forcing it in.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No functional behavior changes; only layout.

## Definition of Done (stay-green)

- [ ] All existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair; an AX5 walkthrough surfaces no clipping, overlap, or vanished UI.
- [ ] PR opened with `Refs #10` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `polish`, `a11y`, `phase-9-hardening`.
