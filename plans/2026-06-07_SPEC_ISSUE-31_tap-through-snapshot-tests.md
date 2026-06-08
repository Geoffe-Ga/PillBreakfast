# SPEC: Issue #31 — Tap-Through Snapshot Tests and Liquid Glass Visual-Review PR Template

| Field | Value |
|---|---|
| Issue | #31 |
| Phase | 3 (High-Risk Confirmation + Liquid Glass First Pass) |
| Epic | #4 |
| Labels | `spec-decomposition`, `polish`, `phase-3-high-risk`, `tests` |
| Status | Draft |
| Date | 2026-06-07 |
| Related issues | Predecessor: EPIC_04_ISSUE_04 (settings hold duration); successor: none |
| Authored by | Test Specialist |

---

## 1. Summary

Add golden snapshot tests covering `MarkTakenView` (high-risk idle, mid-hold, and completed states; non-high-risk idle and confirmed state) and `QueueSuccessView` (shimmer-armed state). Extend `.github/pull_request_template.md` with a four-item "Visual Review Checklist" that gates every PR touching Liquid Glass surfaces. No behavioral changes.

---

## 2. Problem Statement / Motivation

Phase 3 introduced the press-and-hold ring (`HighRiskConfirmButton`), the Liquid Glass background (`glassBackground()`), and the success shimmer (`ShimmerModifier`). These are correctness-critical for the product: a ring that fills too early would let a high-risk dose slip through on a casual tap; an un-glassed screen violates the design language that makes the product recognizable. Today there are no automated checks that the visual structure of these screens is what was intended when Phase 3 shipped.

The Phase 3 gate in SPEC §10 is explicitly a visual review ("looks like a watchOS 26 native app, not a port of iOS chrome. Press-and-hold can't be triggered accidentally."). Without snapshot tests and a PR-level checklist, the gate degrades to "it looked fine at ship time" with no regression net.

---

## 3. Goals and Non-Goals

**Goals:**
- Golden snapshots of all meaningful UI states for `MarkTakenView` and `QueueSuccessView`, committed alongside the test file and run on every PR targeting `main`.
- A PR template checklist section that forces explicit review of four Liquid Glass invariants for any PR touching design-system, watch, or iOS regimen surfaces.
- Tests run on a fixed simulator (Apple Watch Series 11 46mm), fixed locale (en_US), and fixed timezone (America/New_York) for determinism.
- Zero functional changes to production code.

**Non-Goals:**
- Snapshot tests for every view in the app (this is not a coverage-percentage exercise).
- iOS snapshot tests (the watch surface is the primary surface; iPhone is setup-only).
- Automated visual diffing with a CI artifact server or Percy-style remote review.
- Replacing the manual visual-review checklist with automation.

---

## 4. Background and Current State

**Relevant source files (Phases 0–6 shipped, 166 Swift files):**

- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift` — the primary target. Renders one of two confirm buttons depending on `isHighRisk`. Uses `LiquidGlassTheme.Typography`, `LiquidGlassTheme.Colors.highRiskAccent`, and `glassBackground()`.
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/HighRiskConfirmButton.swift` — press-and-hold ring, amber accent, three states: idle (ring empty), holding (ring filling), completed (ring full).
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/HoldProgress.swift` — pure state machine (`HoldProgress.State`: `.idle`, `.holding(startedAt:)`, `.completed`, `.cancelled`). Deterministic; `progress(at:)` takes an injected `Date` — this is how we freeze mid-hold state for snapshot testing.
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/SingleTapConfirmButton.swift` — non-high-risk confirm button, `.borderedProminent` style.
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/QueueSuccessView.swift` — success state with `ShimmerModifier`, `Motion.dramatic` scale-in, auto-dismisses via `Task.sleep`.
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/DesignSystem/View+GlassBackground.swift` — `.glassBackground()` extension applying `.glassEffect()` unconditionally (watchOS 26 floor).
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/DesignSystem/ShimmerModifier.swift` — one-shot diagonal band sweep, no-op under Reduce Motion.

**Existing test targets:**
- `PillBreakfast Watch App Watch AppTests/TapThroughQueue/HoldProgressTests.swift` — comprehensive unit tests for `HoldProgress` state machine (13 test cases covering all state transitions using Swift Testing). This is the right model to follow.
- `PillBreakfast Watch App Watch AppUITests/` — currently contains only the boilerplate XCTest stub and a launch performance test. The `PillBreakfastUITests/MemoryReproUITests.swift` is an investigation-only repro driver, not a product test.

**Snapshot library status:** No snapshot library is currently a dependency. The `.xcodeproj` has no SPM package manifest (`Package.resolved` does not exist; CLAUDE.md confirms "no Swift package manifest yet"). There is no `assertSnapshot` or `SnapshotTesting` import anywhere in the codebase. The only mention is in the original issue brief (`plans/git-issues/EPIC_04_ISSUE_05_snapshot-tests-and-visual-review.md`).

**PR template status:** `.github/pull_request_template.md` does not currently exist. The `.github/` directory contains only workflow files (`ci.yml`, `claude-code-review.yml`, `claude.yml`, `iteration-trigger.yml`, `ralph-next.yml`).

---

## 5. Detailed Design

### 5.1 Snapshot Library Choice

**Recommended: `swift-snapshot-testing` by Point-Free** (`https://github.com/pointfreeco/swift-snapshot-testing`, current stable tag at time of implementation).

Rationale over alternatives:

| Option | Assessment |
|---|---|
| `swift-snapshot-testing` (Point-Free) | Industry standard for SwiftUI snapshot testing. Supports `swiftUIView` strategy with injected environment. Renders to `UIImage` on simulator. Well-maintained and Swift 6 compatible. |
| `XCTest`'s `XCTAttachment` with `UIGraphicsImageRenderer` | Built-in but not a diff-based snapshot framework — no golden file management, no automatic failure on diff. Requires custom plumbing to achieve the same outcome. |
| `AccessibilitySnapshot` (Airbnb) | Focused on accessibility rendering, not visual fidelity. Not the right tool here. |

The choice is `swift-snapshot-testing`. The engineer implementing this issue must document the specific version pinned in a comment at the top of `TapThroughSnapshotTests.swift`.

### 5.2 Adding the SPM Dependency — No Package.swift Exists

CLAUDE.md notes there is no Swift package manifest. Dependencies must be added through the Xcode project UI or via `Package.swift` introduction. The engineer should add `swift-snapshot-testing` using Xcode's "Add Package Dependency" flow:

1. Select `PillBreakfast.xcodeproj` in Xcode.
2. File > Add Package Dependencies... > paste the GitHub URL.
3. Pin to the latest stable tag (not `main`).
4. Link the library to `PillBreakfast Watch App Watch AppTests` target only — not the production watch app or the iOS app.

The `xcodeproj` will record the resolved version in `PillBreakfast.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. That file must be committed. Document the version in both the PR description and in a comment in the test file.

### 5.3 Test File Location

`PillBreakfast Watch App Watch AppTests/Snapshots/TapThroughSnapshotTests.swift`

This is a new directory under the watch test target. The issue brief from `EPIC_04_ISSUE_05` specified `PillBreakfastWatchTests/Snapshots/` — the actual target directory is `PillBreakfast Watch App Watch AppTests/` (matching the scheme named `PillBreakfast Watch App Watch App`).

Snapshots are committed as PNG files under:
`PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/TapThroughSnapshotTests/`

This is where `swift-snapshot-testing` writes by default when using file-based snapshot storage.

### 5.4 Simulator Fixture

All snapshot tests must run on:
- **Device:** Apple Watch Series 11 (46mm)
- **Locale:** `en_US`
- **Timezone:** `America/New_York`
- **Color scheme:** system default (light)

These values must be injected into the `SwiftUI.Environment` for each snapshot rather than relying on the running simulator's settings, to keep the tests deterministic across developer machines and CI environments. Locale and timezone are specified at the `xcodebuild test` invocation level via `-testLanguage en -testRegion en_US` (CLAUDE.md build command convention) and additionally locked in the test via explicit `Calendar`/`TimeZone` injection where timing affects rendering.

### 5.5 Rendering Liquid Glass Deterministically

Liquid Glass uses `.glassEffect()`, which on watchOS 26 is a translucent, refractive material. This material responds to the content behind the view (the wallpaper). On a simulator with no wallpaper, the glass background renders as a semi-transparent dark layer over the simulator's system background. This is acceptable for snapshot testing because:

1. The simulator always presents the same background for a given OS version + device size.
2. We are testing structure (layout, typography tokens, ring presence, color accent) not pixel-perfect glass refraction.
3. Snapshot comparisons use a tolerance threshold (see §5.6).

**Important:** `QueueSuccessView` uses `Task.sleep` for timing the shimmer arm and auto-dismiss. These must NOT be exercised by snapshot tests — `Task.sleep` as a synchronization primitive is explicitly forbidden by the testing constraints in CLAUDE.md. Instead, the snapshot tests inject the relevant sub-views directly with their state pre-configured (see §6 for how this is done per view).

### 5.6 Snapshot Precision and Tolerance

Use `swift-snapshot-testing`'s `precision` parameter set to `0.98` (98% pixel match required). This tolerance absorbs sub-pixel antialiasing differences between Xcode versions while still catching meaningful structural regressions. Do not set tolerance so high (e.g., 0.8) that the ring disappearing would pass.

### 5.7 Visual Review PR Template

Create `.github/pull_request_template.md`. The template applies to all PRs; the Visual Review Checklist section is conditionally relevant (the text explains when to complete it).

The full template content:

```markdown
## Summary

<!-- What does this PR do? One or two sentences. -->

## Testing

<!-- What tests cover this change? How did you verify it locally? -->

- [ ] `xcodebuild test` passes for both schemes (iOS + watchOS)
- [ ] `pre-commit run --all-files` is clean
- [ ] App builds and runs on the paired iPhone + Apple Watch Series 11 (46mm) simulator pair

## Visual Review Checklist (Liquid Glass)

**Complete this section for any PR that:**
- touches files under `Shared/DesignSystem/`
- touches files under `PillBreakfast Watch App Watch App/` (any subdirectory)
- touches files under `PillBreakfast/RegimenTab/`
- is labeled `design-system`, `phase-3-high-risk`, or `polish`

If none of the above apply, check "N/A" and leave the rest blank.

- [ ] N/A — this PR does not touch Liquid Glass surfaces
- [ ] All new or changed screens apply `.glassBackground()` on their root container (not stacked glass-on-glass — apply once per visible leaf screen)
- [ ] All typography uses `LiquidGlassTheme.Typography` helpers — no inline `.font(.title)`, `.font(.caption)`, or raw `Font` values
- [ ] Color audit passed: the only non-system accent color in any changed view is `LiquidGlassTheme.Colors.highRiskAccent`, and it appears only on high-risk confirmation surfaces (SPEC §9, CLAUDE.md conventions)
- [ ] Negative space respected: watch screens show one medication name, one dosage figure, one primary action button — no additional chrome or decorative elements added

## Snapshot Test Update

If this PR changes the visual output of `MarkTakenView`, `HighRiskConfirmButton`, `QueueSuccessView`, or any view in `Shared/DesignSystem/`:

- [ ] Snapshot golden files updated (`PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/`) and the diff is intentional
- [ ] If snapshots were NOT updated despite visual changes to the above views, explain why:

## References

<!-- Issue numbers, SPEC sections, related PRs -->
```

### 5.8 CI Integration for Snapshot Tests

Snapshot tests live in the `PillBreakfast Watch App Watch App Watch App` scheme's test target. They run automatically when the full watchOS test suite runs:

```bash
xcodebuild test \
  -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' \
  -testLanguage en \
  -testRegion en_US
```

The `ci.yml` currently has the `xcodebuild test` step commented out with a TODO. Enabling the snapshot tests is the intended trigger for un-commenting that step (or a separate CI step). The engineer implementing this issue must un-comment the watchOS build-and-test step (not just build) for both the iOS and watchOS schemes.

**Snapshot golden files must be committed to the repository.** They go under `PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/` and are tracked in git. CI fails when a snapshot diff is detected (non-zero exit from `xcodebuild test`). Updating snapshots requires running the tests locally with `record: true` and committing the new PNGs.

The `claude-code-review.yml` reviewer will automatically flag unexpected snapshot diffs in PR feedback. The PR template checklist (§5.7) requires the author to explicitly acknowledge whether snapshot updates are intentional.

---

## 6. Concrete Test Cases / Scenarios

All tests use `XCTest` (not Swift Testing) because `swift-snapshot-testing`'s `assertSnapshot` is an `XCTAssert`-family function. The test struct is a `final class` inheriting from `XCTestCase`.

Each test:
1. Constructs the view with deterministic parameters (no `@Environment` injection of live stores — use default `init` parameters that fall back correctly, as `MarkTakenView` already does for `preferencesStore: nil`).
2. Wraps the view in a fixed-size frame matching the 46mm Apple Watch screen (184×224 pt).
3. Calls `assertSnapshot(of: view, as: .image(on: .watchOS(.series9_45mm)), record: false)`.
4. Includes a comment explaining which state is being pinned and why it matters.

### Scene 1: MarkTakenView — Non-High-Risk, Idle

**Why:** Pins the baseline monochromatic layout. No color accent, single "Mark Taken" button visible, glass background present.

Parameters: `medicationName: "Vitamin D"`, `detail: "2000 IU · 1 capsule"`, `isHighRisk: false`, `colorHex: nil`, `mealHeader: nil`.

**Mutant-killing purpose:** If `glassBackground()` is accidentally removed or `isHighRisk` branching is reversed, this snapshot fails.

### Scene 2: MarkTakenView — Non-High-Risk with Meal Header

**Why:** Pins the `mealHeader` caption rendering path. "Pill Breakfast · 1 of 3" appears above the medication name in `LiquidGlassTheme.Typography.caption` style.

Parameters: `medicationName: "Vitamin D"`, `detail: "2000 IU · 1 capsule"`, `isHighRisk: false`, `colorHex: nil`, `mealHeader: "Pill Breakfast · 1 of 3"`.

### Scene 3: MarkTakenView — High-Risk, Idle (Ring Empty)

**Why:** Pins the amber accent presence, ring structure at 0% progress, and the "Hold to confirm" hint label. This is the most safety-critical visual state — if the press-and-hold ring is absent, a user might not know to hold.

Parameters: `medicationName: "Lithium 300mg"`, `detail: "300mg · 1 tablet"`, `isHighRisk: true`, `colorHex: "#FFAA00"`.

The `HighRiskConfirmButton` is rendered with its default `holdDuration: 0.5`. To freeze the ring at 0%, the `HoldProgress` state machine starts in `.idle` — no action needed; this is the default.

**Important:** `HighRiskConfirmButton` uses a `TimelineView(.animation(paused: !hold.isHolding))` that is paused when not holding, so the snapshot captures a static frame cleanly.

### Scene 4: MarkTakenView — High-Risk, Mid-Hold (Ring at 50%)

**Why:** Pins the ring-filling visual: the amber arc covers half the circle, the ring has `lineCap: .round`, rotation offset is -90 degrees. This is the most technically tricky snapshot because `HoldProgress.progress(at:)` is time-dependent.

**Approach:** `HoldProgress` exposes its state machine directly. Construct a `HoldProgress(holdDuration: 0.5)` instance, call `begin(at: Date(timeIntervalSince1970: 0))`, then pass `Date(timeIntervalSince1970: 0.25)` as the "now" to freeze progress at 0.5. However, `HighRiskConfirmButton` uses `TimelineView` which takes the current date — it cannot accept an injected date from outside.

**Resolution:** The snapshot for mid-hold state is achieved by injecting the hold state into `HighRiskConfirmButton` via a modified initializer, or by snapshotting `HoldProgress`-driven ring view components directly. The engineer should expose a `@testable` initializer on `HighRiskConfirmButton` that accepts a pre-configured `HoldProgress` instance, or extract the ring into a `RingView(progress: Double)` pure view that can be snapshotted at any progress value.

The snapshot asserts: amber arc is present, arc length is approximately half-circle, background ring stroke is at 25% opacity.

### Scene 5: MarkTakenView — High-Risk, Completed (Ring Full)

**Why:** Pins the completed state. Ring is 100% filled. This verifies the `.completed` branch of `progress(at:)` returns 1.0 and the ring renders fully closed.

Inject a `HoldProgress` in `.completed` state (call `begin(at:)` then `complete()`).

### Scene 6: QueueSuccessView — Pre-Shimmer (Appeared, Shimmer Not Yet Armed)

**Why:** Captures the hero checkmark seal at full opacity with `didAppear = true` but `shimmerArmed = false`. The label "All pills logged" is visible without the shimmer overlay.

**Approach:** `QueueSuccessView` uses `.task { try await Task.sleep(...) }` to arm the shimmer and later call `onDone()`. Neither of these should fire in a snapshot test. Snapshots are synchronous renders — the `.task` modifier fires its async closure, but the snapshot is captured before the first `Task.sleep` completes. Set `record: true` once to capture the initial appear state and confirm that the shimmer band is not visible.

To guarantee the `shimmerArmed = false` state without relying on timing, extract the body's appearance logic into a view that accepts `didAppear: Bool` and `shimmerArmed: Bool` as parameters (or use `@testable` access to set `@State` via a mirror, which is fragile). The preferred approach is a simple preview-friendly `init` override that uses `_didAppear = State(initialValue: true)` and `_shimmerArmed = State(initialValue: false)` — exposing these only in the test target via `@testable`.

**Why this scene matters:** If the Reduce Motion path accidentally always shows `shimmerArmed = true`, the shimmer sweeps on first render. If the checkmark disappears (opacity regression), this snapshot fails.

### Scene 7: QueueSuccessView — Shimmer Armed

**Why:** Captures "All pills logged" label with the `ShimmerModifier` applied (`shimmerArmed = true`). The shimmer band is at phase 0 (start position, off-screen left) because snapshots capture the initial frame before `withAnimation` fires.

Initialize with `_shimmerArmed = State(initialValue: true)`.

---

## 7. Edge Cases and Determinism Concerns

**Liquid Glass rendering variance.** The `.glassEffect()` modifier uses real system compositor effects. On simulators, this renders as a dark translucent layer over the simulator's background. The exact shade can vary by Xcode/simulator runtime version. The `precision: 0.98` tolerance absorbs minor rendering variance. If snapshots become flaky after a simulator runtime update, update the golden files deliberately and commit with a comment explaining the runtime version change.

**TimelineView in HighRiskConfirmButton.** The `ring` var uses `TimelineView(.animation(paused: !hold.isHolding))`. When `isHolding` is false (scenes 3 and 5), the timeline is paused — the ring is static. When `isHolding` is true (scene 4), the timeline would normally animate continuously. The snapshot captures a single frame; the `TimelineView` context provides `Date.now` at capture time. To freeze mid-hold state precisely, the ring sub-view must be separable from the gesture layer (see Scene 4 design note above).

**`Task.sleep` in QueueSuccessView.** Snapshot tests are synchronous XCTest runs. The `.task` modifier's async work begins executing in a Task on the main actor, but the snapshot is captured before any `await` yields. The initial render (before the first sleep completes) is what gets snapshotted. This is the desired behavior but must be documented clearly in the test file to prevent future engineers from adding assertions that expect the post-sleep state.

**Reduce Motion.** The snapshot test suite should include one variant of `QueueSuccessView` with `\.accessibilityReduceMotion` set to `true` in the environment. Under Reduce Motion, `didAppear` and `shimmerArmed` both have no effect on opacity (the view is visible from frame 0, shimmer is suppressed). This variant prevents a regression where Reduce Motion accidentally hides content.

**Color scheme.** Snapshot only in system default (typically dark on watchOS). Light mode on watchOS is not the primary concern for Liquid Glass. If watchOS 26's system color scheme changes this assumption, revisit.

**Locale with Arabic/RTL.** Not in scope for v1 but note that SF Pro Rounded is the font for medication names — RTL layout would change snapshot comparison. Fixed `en_US` locale prevents this variance.

---

## 8. CI Integration

The snapshot tests are part of the `PillBreakfast Watch App Watch App` test scheme. Once the `ci.yml` watchOS test step is un-commented (as part of this issue's implementation), every push to any branch runs the full watchOS test suite including snapshots.

**Scheme:** `PillBreakfast Watch App Watch App`
**Destination:** `platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest`
**Additional flags:** `-testLanguage en -testRegion en_US`

Snapshot failures appear as `XCTFail` in the test output with a path to the generated "actual" PNG and the expected golden PNG side by side in the Xcode test results. In CI, the failure appears in the `xcodebuild test` output and causes a non-zero exit, blocking PR merge.

The `claude-code-review.yml` reviewer is prompted to check test coverage and code quality; it will naturally flag a PR that changes `MarkTakenView` or `HighRiskConfirmButton` without updating the corresponding snapshot files.

**Running snapshots locally:**

```bash
# Run only the snapshot test suite:
xcodebuild test \
  -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest' \
  -testLanguage en \
  -testRegion en_US \
  -only-testing:'PillBreakfast Watch App Watch AppTests/TapThroughSnapshotTests'

# Record new golden files (run after intentional visual changes):
# Set `record: true` in assertSnapshot calls, run tests, then set back to false and commit.
```

---

## 9. Risks and Open Questions

**Risk: `.glassEffect()` renders differently between Xcode 26 beta versions.** The CI image may use a different Xcode 26.x than the developer's local environment. If snapshot golden files are generated on Xcode 26.0 but CI runs on 26.1 with changed compositor behavior, all glass snapshots fail. Mitigation: generate golden files on the CI Xcode version (run once on CI with `record: true` via `xcodebuild test -testPlan record`), or accept a slightly looser `precision: 0.95` for glass-background-containing tests specifically.

**Risk: `swift-snapshot-testing` compatibility with Swift 6 strict concurrency.** As of mid-2025, Point-Free's library supports Swift 6 but its `@MainActor` isolation story may require `@testable import` adjustments. The engineer should verify this at the pinned version.

**Risk: watchOS snapshot rendering requires a booted simulator.** On CI, `xcrun simctl boot` must succeed before `xcodebuild test` runs. The `ci.yml` already has `xcrun simctl shutdown all` commented near the test step — this must be enabled alongside the test step to ensure a clean simulator state.

**Open question: Should iOS app views (e.g., `EditMedicationView`, `HistoryTabView`) get snapshots?** Out of scope for this issue. The issue brief limits scope to the watch tap-through queue and success view. iOS snapshot tests can be a follow-up issue under Epic 9 (Polish).

**Open question: `swift-snapshot-testing` vs. a first-party Apple approach.** Xcode 16+ offers `XCUIApplication.screenshot()` for UI-test-level screenshots but that is a black-box capture, not a SwiftUI-level golden test. No first-party equivalent of `assertSnapshot(of: swiftUIView, ...)` exists in the Apple test frameworks as of 2026-06. The Point-Free library is the right choice.

---

## 10. Decomposition Hints

This issue is relatively self-contained but touches two distinct deliverables. A single PR is appropriate (per the issue brief). However, if the engineer wants to split:

- **Child A:** Add `swift-snapshot-testing` dependency, create the test file with golden-file recording enabled, capture all 7 scenes, commit PNGs, set `record: false`.
- **Child B:** Create `.github/pull_request_template.md` with the Visual Review Checklist.
- **Child C:** Un-comment the `ci.yml` watchOS `xcodebuild test` step and verify CI passes end-to-end.

If done as one PR (preferred), the order is: dependency → test file with `record: true` run → commit PNGs → set `record: false` → PR template → CI step → open PR.

---

## 11. Acceptance Criteria / Done-Done

These map to SPEC §10 Phase 3 gate ("Visual review — looks like a watchOS 26 native app; press-and-hold can't be triggered accidentally") as a durable automated regression net.

- [ ] `swift-snapshot-testing` is pinned at a specific version tag (not `main`) and the resolved version appears in `PillBreakfast.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, committed to the repository.
- [ ] `PillBreakfast Watch App Watch AppTests/Snapshots/TapThroughSnapshotTests.swift` exists and contains `XCTestCase` snapshot tests for all 7 scenes defined in §6.
- [ ] Golden PNG files exist under `PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/TapThroughSnapshotTests/` for all 7 scenes, committed and correct (not blank, not a crash screen).
- [ ] `assertSnapshot` calls use `record: false` (not `record: true`) so CI fails on unexpected diffs.
- [ ] `precision: 0.98` (or documented rationale for any deviation) is set on all `assertSnapshot` calls.
- [ ] `.github/pull_request_template.md` exists with the Visual Review Checklist section matching the template in §5.7.
- [ ] `xcodebuild test` for the watchOS scheme passes locally with all 7 snapshot tests green.
- [ ] The `ci.yml` watchOS test step is un-commented and the build passes in CI with all snapshot tests green.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR description documents the version of `swift-snapshot-testing` chosen and explains why (one paragraph).
- [ ] No functional changes to any production Swift file.
- [ ] No `Task.sleep` in any new test code.

---

## 12. References

- SPEC §7.2 (tap-through queue, one pill per screen)
- SPEC §9 (Liquid Glass design language, phase 3 visual gate)
- SPEC §10 Phase 3 gate definition
- CLAUDE.md: build/test commands, exact scheme names, Swift Testing filter syntax
- CLAUDE.md: "High-risk = press-and-hold", "Color reserved for high-risk", "Watch never gets logging UI on the iPhone"
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/HighRiskConfirmButton.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/HoldProgress.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch App/TapThroughQueue/QueueSuccessView.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/DesignSystem/ShimmerModifier.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/Shared/DesignSystem/View+GlassBackground.swift`
- `/Users/geoffgallinger/Projects/PillBreakfast/PillBreakfast Watch App Watch AppTests/TapThroughQueue/HoldProgressTests.swift` (model for test style)
- `/Users/geoffgallinger/Projects/PillBreakfast/.github/workflows/ci.yml`
- `/Users/geoffgallinger/Projects/PillBreakfast/.github/workflows/claude-code-review.yml`
- `plans/git-issues/EPIC_04_ISSUE_05_snapshot-tests-and-visual-review.md`
- Point-Free `swift-snapshot-testing`: `https://github.com/pointfreeco/swift-snapshot-testing`
