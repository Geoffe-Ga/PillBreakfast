## Role

Placeholder — not ready to pick up.

## Goal

Add iCloud sync for multi-device support via CloudKit-backed SwiftData per SPEC §12.2.

## Context

- **Parent epic:** #11
- **SPEC section:** `plans/SPEC.md` §12.2.
- **Open questions (needs-spec):**
  - Migration path from non-CloudKit SwiftData to CloudKit-backed SwiftData.
  - Conflict resolution for cross-device `DoseEvent` writes (unlikely but possible).
  - Privacy nutrition label delta for CloudKit usage.

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

## Labels

`spec-decomposition`, `future-work`, `needs-spec`.
