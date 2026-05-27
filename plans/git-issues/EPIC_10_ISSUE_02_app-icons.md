## Role

You are a senior iOS engineer producing the app icon set.

## Goal

Add all required iOS and watchOS icon sizes from a single 1024x1024 master. Verify `xcodebuild`'s asset catalog passes.

## Context

- **Parent epic:** #10
- **Predecessor issue(s):** #EPIC_10_ISSUE_01_NUMBER.
- **SPEC section:** §10 Phase 9.
- **Files involved:** `iOSApp/Assets.xcassets/AppIcon.appiconset/`, `WatchApp Watch App/Assets.xcassets/AppIcon.appiconset/`.
- **Prior decisions (locked):** monochromatic glass aesthetic translates to a clean wordmark / pill silhouette. Engineer picks the exact mark; design review is part of the PR.
- **State of the world:** Default Xcode-generated icons present.

## Output Format

A single PR containing:

- [ ] 1024x1024 master added to `Submission/assets/`.
- [ ] All derived sizes generated and slotted into the catalog.
- [ ] PR includes a screenshot of the iPhone home screen + watch app grid showing the new icon.

## Constraints

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Build passes; new icon visible.

## Definition of Done (stay-green)

- [ ] `xcodebuild` asset validation passes.
- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] App builds and runs; icon appears on the simulator pair.
- [ ] PR opened with `Refs #10` and `Closes #EPIC_10_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`.
