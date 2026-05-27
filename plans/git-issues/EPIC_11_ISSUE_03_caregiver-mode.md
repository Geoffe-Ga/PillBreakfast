## Role

Placeholder — not ready to pick up. Likely v2.

## Goal

Share regimen visibility with a caregiver / partner per SPEC §12.3.

## Context

- **Parent epic:** #11
- **SPEC section:** `plans/SPEC.md` §12.3.
- **Open questions (needs-spec):**
  - **Requires a real backend.** Out of scope until a backend exists.
  - Privacy model: which surfaces are shared (regimen only? dose events? PRN totals?).
  - Authentication.

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

## Labels

`spec-decomposition`, `future-work`, `needs-spec`, `v2`.
