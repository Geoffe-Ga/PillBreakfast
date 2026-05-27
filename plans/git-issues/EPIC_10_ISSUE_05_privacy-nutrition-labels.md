## Role

You are a senior iOS engineer filling out the App Store privacy nutrition labels honestly.

## Goal

Document data collection in `Submission/privacy-nutrition.md` and configure the App Store Connect metadata fields to match. PillBreakfast reads HealthKit Medications (with explicit purpose), writes no data off-device, uses no third-party SDKs (assuming MetricKit was chosen in EPIC_10_ISSUE_04).

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_04_NUMBER.
- **SPEC section:** §10 Phase 9 ("Privacy nutrition labels (HealthKit usage disclosure)").
- **Files involved:**
  - `Submission/privacy-nutrition.md` (new) — the source of truth for the App Store Connect entries.
  - `iOSApp/Info.plist` — confirm usage descriptions match the labels.
- **Prior decisions (locked):**
  - **No data leaves the device** (apart from `WCSession` phone <-> watch sync, which is local).
  - **HealthKit reads are voluntary and read-only.**
- **State of the world:** Crash reporting in place.

## Output Format

A single PR containing:

- [ ] `privacy-nutrition.md` listing every data category Apple asks about with the precise answer.
- [ ] Cross-check: every `NS*UsageDescription` in `Info.plist` is reflected.
- [ ] PR body includes the App Store Connect entries that will be filed.

## Constraints

**Honest labels only.** Overclaiming and underclaiming are both grounds for review rejection.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Documentation; no code regression.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
