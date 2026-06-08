# Epic — Tap-through snapshot tests & Liquid Glass visual-review PR template

## Outcome

The Phase 3 visual gate ("looks like a watchOS 26 native app; press-and-hold can't be triggered accidentally") becomes a durable, automated regression net. Golden snapshots pin every meaningful state of `MarkTakenView` and `QueueSuccessView` (high-risk press-and-hold ring at idle / mid-hold / completed, non-high-risk idle and meal-header, success pre-shimmer / shimmer-armed / reduce-motion). A PR template forces explicit review of four Liquid Glass invariants, and the watchOS `xcodebuild test` step in CI is un-commented so snapshots run on every push.

## Spec sections

- `plans/2026-06-07_SPEC_ISSUE-31_tap-through-snapshot-tests.md` (full spec)
- SPEC §7.2 (tap-through queue, one pill per screen), §9 (Liquid Glass design language), §10 Phase 3 gate

## Locked decisions inherited from the spec

- **Library: `swift-snapshot-testing` (Point-Free)**, pinned to a stable tag (not `main`), linked to the watch test target only.
- **No Swift package manifest exists yet** — the dependency is added through Xcode's "Add Package Dependencies…" UI; the resolved `Package.resolved` is committed.
- **Watch surface only.** No iOS snapshot tests (iPhone is setup-only).
- **Determinism:** Apple Watch Series 11 (46mm), `en_US`, `America/New_York`, system default color scheme; `precision: 0.98`.
- **No `Task.sleep` in test code.** `QueueSuccessView` states are pinned by injecting `didAppear` / `shimmerArmed`, never by waiting on the `.task` timing.
- **Zero functional changes to production code** — only `@testable` initializers / extracted pure sub-views (e.g. a `RingView(progress:)`) where needed to freeze state.

## Child issues

- [ ] **Issue: skeleton** — add the `swift-snapshot-testing` dependency via Xcode SPM UI, commit `Package.resolved`, create `TapThroughSnapshotTests.swift` with the first golden snapshot (Scene 1, non-high-risk idle) recorded and committed, `record: false`.
- [ ] **Issue: core scene set** — the remaining six scenes incl. the high-risk ring states (idle / mid-hold 50% / completed), meal-header, and `QueueSuccessView` pre-shimmer / shimmer-armed / reduce-motion. Extract `RingView`/`@testable` inits as needed.
- [ ] **Issue: PR template + CI wiring** — create `.github/pull_request_template.md` with the Visual Review Checklist and un-comment the watchOS (and iOS) `xcodebuild test` step in `ci.yml`.

## Acceptance for the epic

- All 7 scenes have committed, non-blank golden PNGs under `PillBreakfast Watch App Watch AppTests/Snapshots/__Snapshots__/TapThroughSnapshotTests/`.
- `assertSnapshot` calls use `record: false` and `precision: 0.98` (or documented deviation).
- `.github/pull_request_template.md` exists with the four-item Liquid Glass checklist and the snapshot-update section.
- The watchOS test step in `ci.yml` is enabled and CI is green end-to-end.
- No functional changes to production Swift; no `Task.sleep` in test code; `pre-commit run --all-files` clean.

## Out of scope (for this epic)

- iOS app view snapshots (`EditMedicationView`, `HistoryTabView`) — follow-up under Phase 9 polish.
- Automated visual diffing with a CI artifact server / Percy-style remote review.
- Replacing the manual checklist with automation.

## Sequencing notes

- Parent issue: **#31** (child of phase-epic **#4**, Phase 3).
- Predecessor: EPIC_04_ISSUE_04 (settings hold duration). Snapshots pin the shipped Phase 3 surfaces, so this runs after the high-risk confirmation UI is in place.
- Children chain: skeleton → core scene set → PR template + CI wiring.
