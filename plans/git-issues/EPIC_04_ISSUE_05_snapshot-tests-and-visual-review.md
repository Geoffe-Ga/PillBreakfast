## Role

You are a senior iOS test engineer setting up SwiftUI snapshot tests and embedding a manual visual-review checklist in the project's PR template.

## Goal

Add snapshot tests covering the high-risk vs. non-high-risk tap-through screens (idle, mid-hold, completed). Add a manual visual-review checklist to `.github/pull_request_template.md` that every Liquid-Glass-touching PR completes.

## Context

- **Parent epic:** #4
- **Predecessor issue(s):** #EPIC_04_ISSUE_04_NUMBER.
- **SPEC section:** `plans/SPEC.md` §9 (visual review explicitly called out as a phase gate).
- **Files involved:**
  - `PillBreakfastWatchTests/Snapshots/TapThroughSnapshotTests.swift` (new). Use `swift-snapshot-testing` (or whichever snapshot library the engineer picks; document the choice in the PR).
  - `.github/pull_request_template.md` (new or extended): add a "Visual Review Checklist" section.
- **Prior decisions (locked):**
  - Snapshot tests run on a fixed simulator size (Apple Watch Series 11 46mm) with a fixed locale (en_US) and a fixed timezone (America/New_York) to keep snapshots stable.
  - The visual review checklist applies to any PR with the `design-system` label.
- **State of the world:** EPIC 04 functionality is in place; we just need durable visual checks.

## Output Format

A single PR containing:

- [ ] Snapshot dependency added (Swift Package Manager). Document the choice between `swift-snapshot-testing` (pointfree) and Apple's `XCTest` view rendering.
- [ ] Snapshot tests for: high-risk `MarkTakenView` idle / mid-hold / completed; non-high-risk `MarkTakenView` idle / completed; `QueueSuccessView` shimmering.
- [ ] PR template extension with a four-item visual review checklist: glass background present; typography tokens used; color audit (no unintended color); negative space respected.

## Examples

```yaml
## Visual Review Checklist (Liquid Glass)

For PRs labeled `design-system` or that touch any view under `Shared/DesignSystem/`,
`WatchApp Watch App/`, or `iOSApp/RegimenTab/`:

- [ ] All new/changed screens wrap their root container in `.glassBackground()`
- [ ] All typography uses `LiquidGlassTheme.Typography` helpers (no inline `.font(.title)`)
- [ ] No unintended color: only `LiquidGlassTheme.Colors.highRiskAccent` and only on high-risk surfaces
- [ ] Watch screens look mostly empty: one name, one number, one button (SPEC §9 negative space)
```

## Constraints

**Scope fence:** Don't change behavior. Don't add new screens. This is a testing + tooling issue.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No functional change; snapshot tests pass against the just-merged EPIC 04 visuals.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes), including snapshots.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #4` and `Closes #EPIC_04_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-3-high-risk`, `tests`.
