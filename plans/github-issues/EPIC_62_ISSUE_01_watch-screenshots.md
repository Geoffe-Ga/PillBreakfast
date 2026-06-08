## Role

You are a watchOS UI engineer and capture technician producing the five Apple Watch App Store screenshots for PillBreakfast v1, plus the shared anonymized regimen seed and the capture runbook the rest of #62 depends on.

## Goal

Define and seed the §5.2 anonymized regimen (Med A–E, Ingredient A/B), write the §5.3 capture procedure into `Submission/screenshot-script.md` as the runbook, and capture the five watch screenshots (W-1…W-5) at 396×484pt @2x on the Apple Watch Series 11 (46mm) simulator — each showing a specific named surface with the 9:41 status bar and no real data.

## Context

- **Parent epic:** #62.
- **Predecessors:** #61 (icon merged — it is visible on the watch app grid behind the captures). This child also **owns the shared regimen seed** that the iPhone-screenshots child and the privacy child reference.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-62_screenshots-marketing-copy.md` §4 (watch surfaces available), §5.1 watch shot-list (W-1…W-5 with captions + capture notes), §5.2 (anonymized seed), §5.3 (capture procedure / filename convention), §7 (watch resolution, mid-hold harness, status-bar override edge cases).
- **Files involved:**
  - `Submission/screenshots/W-1_pending-queue.png` (new) — `MarkTakenView` single-pill card, "Med A · 300 mg · 1 tablet".
  - `Submission/screenshots/W-2_high-risk-hold.png` (new) — `HighRiskConfirmButton` mid-hold, ring at ~60–70%.
  - `Submission/screenshots/W-3_success-state.png` (new) — `QueueSuccessView` / `MealCompletionView` glass shimmer.
  - `Submission/screenshots/W-4_prn-list.png` (new) — `PRNListView` with ingredient-aware running totals.
  - `Submission/screenshots/W-5_safety-warning.png` (new) — `SafetyWarningView` interstitial (Ingredient B · ceiling).
  - `Submission/screenshot-script.md` (existing stub → fill with the §5.3 runbook, including the §5.2 seed table).
- **Prior decisions (locked):**
  - Anonymized stand-ins only (no real meds/diagnoses); dark mode preferred for watch (Liquid Glass reads best on the dark face); 9:41 status bar via `xcrun simctl status_bar booted override --time '9:41'`.
  - **W-2 must be a live capture** — `XCUITest` + `xcrun simctl io booted screenshot` during a long-press paused at ~60% progress (or simulator slow-motion). A SwiftUI Preview shim is a documented fallback only, clearly labeled, with a v1.1 replace note.
  - Watch screenshots export at 396×484pt @2x (792×968px); verify the App Store uploader accepts this resolution.

## Output Format

A single PR containing:

- [ ] `Submission/screenshot-script.md` filled with the §5.3 capture procedure (wipe → fresh install → onboard skipping HealthKit → seed the §5.2 regimen → seed 5 days of history → capture in order → filename convention) and the §5.2 seed table embedded so the iPhone/privacy children share one source of truth.
- [ ] Five watch PNGs in `Submission/screenshots/` with the `W-N_*` naming, all anonymized, all 9:41 status bar, all 396×484pt @2x.
- [ ] W-2 shows the press-and-hold ring at an obvious mid-progress fill (30–70%); the PR notes whether it was a live UITest capture or the labeled Preview fallback.
- [ ] PR body includes the per-shot caption text (from §5.1) intended for the App Store gallery, and an anonymization note confirming every visible med name is a §5.2 stand-in.

## Examples

The shared seed table (SPEC §5.2) the runbook must embed:

```
| Stand-in | Class                          | Kind / schedule          | Dosage shown      |
|----------|--------------------------------|--------------------------|-------------------|
| Med A    | Lithium-class (high-risk)      | Maintenance, daily 8:00  | 300 mg · 1 tablet |
| Med B    | Generic supplement             | Maintenance, daily 8:00  | 1000 IU · 1 cap   |
| Med C    | Generic supplement             | Maintenance, daily 8:00  | 500 mg · 1 tablet |
| Med D    | Gabapentin-class PRN           | PRN, ceiling 1200 mg/day | 300 mg/capsule    |
| Med E    | Acetaminophen-class PRN        | PRN, ceiling 4000 mg/day | 500 mg/tablet     |
```

Capture command + filename convention:

```bash
xcrun simctl status_bar booted override --time '9:41'
xcrun simctl io booted screenshot Submission/screenshots/W-1_pending-queue.png
```

## Constraints

**Scope fence:** Watch screenshots, the shared seed definition, and the capture runbook only. **No** iPhone screenshots, **no** marketing-copy deck, **no** privacy audit (sibling children). **No new code to support capture** — every surface must already exist from Phases 1–8; the only permissible code is a UITest harness for the W-2 mid-hold capture.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Captures come from the live, already-shipped watch app on the paired simulator — the app builds and runs unchanged; this child adds only PNGs, the runbook, and (if needed) a screenshot-only UITest.

## Done-Done

- [ ] (if a W-2 UITest harness is added) iOS + watch schemes build & all tests pass via the xcodebuild commands in CLAUDE.md. Otherwise: existing tests still pass (pure asset/content change).
- [ ] Five watch PNGs present, anonymized, 9:41 status bar, 396×484pt @2x; W-2 ring at 30–70% fill; `Submission/screenshot-script.md` runbook + seed table complete.
- [ ] `pre-commit run --all-files` is clean (PNG + Markdown included; secret scan passes).
- [ ] PR opened with `Closes #<this issue>` and `Refs #62`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`
