## Role

Placeholder — not ready to pick up.

## Goal

If Apple Health logs a dose via its own UI, detect via `HKAnchoredObjectQuery` and avoid double-prompting on the watch. Per SPEC §12.4.

## Context

- **Parent epic:** #11
- **SPEC section:** `plans/SPEC.md` §12.4.
- **Architecture constraints carried forward:**
  - HealthKit Medications still iOS-only and read-only.
  - The "found a dose in Health that we'd be about to prompt for" detection must run on iPhone and notify the watch via the existing snapshot channel.
- **Open questions (needs-spec):**
  - Latency: how soon after the Health-logged dose can we suppress the watch prompt? Anchored queries refresh on app launch / background fetch.
  - Matching policy: name match? `healthKitConceptID` match (only works for imported meds)?

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

## Labels

`spec-decomposition`, `future-work`, `needs-spec`.
