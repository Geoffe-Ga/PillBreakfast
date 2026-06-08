## Role

You are a senior iOS/watchOS engineer turning the snapshot suite into an enforced gate. You add the Liquid Glass visual-review PR template and enable the watchOS (and iOS) `xcodebuild test` step in CI so the snapshots actually run and block on regression.

## Goal

`.github/pull_request_template.md` exists with the four-item Liquid Glass Visual Review Checklist and a snapshot-update acknowledgement section. The previously commented-out `xcodebuild test` step in `ci.yml` is un-commented for both the iOS and watchOS schemes (build → test), with the watch destination on Apple Watch Series 11 (46mm) and `-testLanguage en -testRegion en_US`, so the 7 snapshot scenes run on every push and a snapshot diff produces a non-zero exit that blocks merge.

## Context

- **Parent epic:** #31 (child of phase-epic #4 — Phase 3).
- **Predecessors:** EPIC_31_ISSUE_02 (full scene set) — all 7 golden PNGs must be committed and green locally before CI is allowed to gate on them.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-31_tap-through-snapshot-tests.md` §5.7 (PR template — verbatim content), §5.8 (CI integration for snapshots), §8 (CI integration), §9 (Xcode-version/glass-rendering and clean-simulator risks).
- **Files involved:**
  - `.github/pull_request_template.md` (new — use the verbatim template in spec §5.7).
  - `.github/workflows/ci.yml` (un-comment the build-and-test steps; spec notes a commented `xcrun simctl shutdown all` near the test step that must be enabled alongside it for a clean simulator state).
- **Prior decisions (locked):**
  - The PR template content is fixed by spec §5.7 — copy it exactly (Summary / Testing / Visual Review Checklist with the four invariants + N/A row / Snapshot Test Update / References).
  - CI un-comments **`test`**, not just `build`, for both schemes. Watch destination: `platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest`, plus `-testLanguage en -testRegion en_US`.
  - Snapshot golden files are committed and tracked in git; CI fails on a snapshot diff.
  - If glass rendering proves flaky across the CI Xcode version, the sanctioned mitigation is documented (regenerate goldens on the CI Xcode, or a documented `precision` deviation) — not loosening tolerance silently.

## Output Format

A single PR containing:

- [ ] `.github/pull_request_template.md` matching spec §5.7 verbatim, including the four Liquid Glass invariants (glassBackground once per leaf screen; typography via `LiquidGlassTheme.Typography`; only-accent-is-`highRiskAccent`-on-high-risk; negative space respected) and the conditional-completion guidance + N/A row.
- [ ] `ci.yml` watchOS `xcodebuild test` step un-commented (build + test), with the Series 11 (46mm) destination and `-testLanguage en -testRegion en_US`.
- [ ] `ci.yml` iOS `xcodebuild test` step un-commented (build + test).
- [ ] The commented `xcrun simctl shutdown all` (clean-simulator) step enabled alongside the test step, if present.
- [ ] CI green end-to-end on the PR with all 7 snapshot tests passing.

## Examples

PR-template section header set must match spec §5.7 exactly:

```markdown
## Visual Review Checklist (Liquid Glass)

**Complete this section for any PR that:**
- touches files under `Shared/DesignSystem/`
- touches files under `PillBreakfast Watch App Watch App/` (any subdirectory)
- touches files under `PillBreakfast/RegimenTab/`
- is labeled `design-system`, `phase-3-high-risk`, or `polish`
```

CI test invocation (watch scheme) to un-comment:

```bash
xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' \
  -testLanguage en -testRegion en_US
```

## Constraints

**Scope fence:** PR template + CI wiring only. Do **not** add new snapshot scenes or production code changes. Do not re-key or restructure unrelated `ci.yml` jobs; un-comment the existing build/test steps and the clean-simulator step the spec calls out, nothing more.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After this PR, every push runs the full iOS and watchOS test suites in CI, the 7 snapshots gate the watch suite, and a deliberate snapshot diff fails CI — demonstrably (note the verified failure-then-fix in the PR description).

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #31`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `tests`, `edges`, `phase-3-high-risk`, `design-system`, `watch`
