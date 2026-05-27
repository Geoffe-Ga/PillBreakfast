## Role

Placeholder — not ready to pick up.

## Goal

Bind the Apple Watch Ultra Action Button to "Log next pill." Per SPEC §12.5.

## Context

- **Parent epic:** #11
- **SPEC section:** `plans/SPEC.md` §12.5.
- **Open questions (needs-spec):**
  - High-risk meds: same rule as EPIC 08's widget — open to confirm, don't log directly.
  - Implementation likely a single `AppIntent` plus an action-button configuration update.

## Constraints

**One-tap log on high-risk is forbidden.** Inherit from EPIC 04 and EPIC 08.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

## Labels

`spec-decomposition`, `future-work`, `needs-spec`.
