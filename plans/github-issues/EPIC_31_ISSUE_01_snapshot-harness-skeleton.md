## Role

You are a senior iOS/watchOS test engineer wiring the first golden-snapshot harness for PillBreakfast's watch tap-through surface. This is the tracer-skeleton issue: add the snapshot library, prove the pipeline records and replays one golden image deterministically, and commit it — without yet covering every scene.

## Goal

`swift-snapshot-testing` (Point-Free) is a pinned dependency linked to the watch test target only. A new test file `PillBreakfast Watch App Watch AppTests/Snapshots/TapThroughSnapshotTests.swift` exists with exactly one scene — `MarkTakenView` non-high-risk idle (Scene 1 from the spec) — recorded once, committed as a golden PNG, and replaying green with `record: false`. The harness fixes device, locale, timezone, and precision so the same PNG reproduces on any developer machine and on CI.

## Context

- **Parent epic:** #31 (child of phase-epic #4 — Phase 3: High-Risk Confirmation + Liquid Glass First Pass).
- **Predecessors:** EPIC_04_ISSUE_04 (settings hold duration) — the Phase 3 confirm UI must be in place. This is the first child of #31; later children depend on this skeleton.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-31_tap-through-snapshot-tests.md` §5.1 (library choice), §5.2 (adding the SPM dependency — no `Package.swift`), §5.3 (test file location), §5.4 (simulator fixture), §5.6 (precision/tolerance), §6 Scene 1.
- **Files involved:**
  - `PillBreakfast.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (new — created by the Xcode SPM resolve; commit it).
  - `PillBreakfast Watch App Watch AppTests/Snapshots/TapThroughSnapshotTests.swift` (new).
  - `PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/TapThroughSnapshotTests/` (new — golden PNG output dir).
  - `PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift` (the view under test; read-only — no production change).
- **Prior decisions (locked):**
  - **No Swift package manifest exists** (CLAUDE.md: "no Swift package manifest yet"). Add `swift-snapshot-testing` via Xcode's **File > Add Package Dependencies…** UI, pin to the latest **stable tag** (not `main`), and link it to the **`PillBreakfast Watch App Watch AppTests` target only** — not the production watch app, not the iOS app.
  - Determinism fixture: Apple Watch Series 11 (46mm), locale `en_US`, timezone `America/New_York`, system default (light) color scheme.
  - `precision: 0.98` on every `assertSnapshot` call.
  - Snapshot tests are `XCTestCase` (not Swift Testing) because `assertSnapshot` is an `XCTAssert`-family call.

## Output Format

A single PR containing:

- [ ] `swift-snapshot-testing` added via Xcode SPM UI, pinned to a stable tag, linked to the watch test target only; `Package.resolved` committed.
- [ ] `TapThroughSnapshotTests.swift` — a `final class … : XCTestCase` with a header comment recording the exact pinned `swift-snapshot-testing` version.
- [ ] Scene 1 test: `MarkTakenView(medicationName: "Vitamin D", detail: "2000 IU · 1 capsule", isHighRisk: false, colorHex: nil, mealHeader: nil)` wrapped in a 184×224 pt frame, asserted via `assertSnapshot(of:as:record:)` with `precision: 0.98`, `record: false`.
- [ ] The Scene 1 golden PNG committed under `…/__Snapshots__/TapThroughSnapshotTests/` (non-blank, not a crash screen).
- [ ] A comment on the test explaining the state being pinned and its mutant-killing purpose (glass background present, no color accent, `isHighRisk` branch correct).
- [ ] PR description names the chosen `swift-snapshot-testing` version and why (one paragraph).

## Examples

Match the test-style model in `PillBreakfast Watch App Watch AppTests/TapThroughQueue/HoldProgressTests.swift` for naming and comment density. Snapshot call shape:

```swift
// swift-snapshot-testing <X.Y.Z> — pinned stable tag, watch test target only.
assertSnapshot(
  of: view,
  as: .image(precision: 0.98, layout: .fixed(width: 184, height: 224)),
  record: false
)
```

## Constraints

**Scope fence:** Skeleton only — one scene. Do **not** add the remaining six scenes (that is the core child), the PR template, or any CI change (that is the polish child). No functional change to any production Swift file; if `MarkTakenView` cannot be snapshotted as-is, prefer default-parameter construction over a production edit and flag the gap for the core child.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After this PR the watch scheme builds and the full watch test suite passes with exactly one snapshot test, green on `record: false`, on any machine — proving the golden-file pipeline end-to-end before the scene set lands.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #31`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `tests`, `tracer-skeleton`, `phase-3-high-risk`, `design-system`, `watch`
