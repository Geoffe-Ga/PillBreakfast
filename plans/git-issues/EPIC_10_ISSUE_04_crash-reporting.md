## Role

You are a senior Apple-platforms engineer choosing a crash reporting mechanism. You write a short `architectural-decisions`-style trade-off doc before writing code.

## Goal

File a short ADR-style write-up in `plans/decisions/2026-MM-DD_crash-reporting.md` comparing MetricKit + on-device logs vs. Crashlytics vs. Sentry. Pick MetricKit as the default unless the write-up's evaluation surfaces a deal-breaker. Implement the chosen mechanism.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_03_NUMBER.
- **SPEC section:** §10 Phase 9 ("Crash reporting").
- **Files involved (new):**
  - `plans/decisions/<today>_crash-reporting.md`.
  - `Shared/Diagnostics/CrashReporting.swift` — MetricKit subscriber writing diagnostic payloads into the App Group's user-private container.
- **Prior decisions (locked):**
  - **Default to MetricKit** for privacy-label cleanliness.
  - If MetricKit's diagnostic latency is unacceptable (>24h), document the alternative.
- **State of the world:** No crash reporting.

## Output Format

A single PR containing:

- [ ] The ADR.
- [ ] MetricKit subscriber implementation.
- [ ] Tests where possible (subscriber registration smoke test).

## Constraints

**Privacy label cleanliness.** Adding a third-party SDK changes the privacy nutrition label in EPIC_10_ISSUE_05. Document the delta if you go that route.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Crash reporting subscribes and writes to local storage.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-9-hardening`.
