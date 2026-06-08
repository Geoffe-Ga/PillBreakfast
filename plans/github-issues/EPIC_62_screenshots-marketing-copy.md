# Epic — #62 Screenshots & Marketing Copy (App Store submission package)

## Outcome

The non-binary portions of the v1 App Store Connect listing are complete and accurate: the full screenshot set for iPhone + Apple Watch (anonymized data, 9:41 status bar), the production-ready marketing copy deck, and a confirmed-accurate privacy nutrition label. Every artifact honors the product thesis — watch-first logging, iPhone is setup+review only, and HealthKit is **read-only import** (no "writes to Health" claim anywhere). This is the last non-build prerequisite for the Phase 9 TestFlight gate, and it depends on #61 (real icon) being merged first.

## Spec sections

- `plans/2026-06-07_SPEC_ISSUE-62_screenshots-marketing-copy.md` §5.1 (shot-list), §5.2 (anonymized regimen seed), §5.3 (capture procedure), §5.4 (marketing copy deliverable verbatim), §5.5 (privacy-label review), §7 (edge cases), §8 (acceptance).
- `plans/SPEC.md` §1–2 (vision / north-star journeys — copy tone), §3.2 (HealthKit read-only), §6 (iPhone setup+review only), §7 (watch surfaces), §9 (Liquid Glass).
- `CLAUDE.md` — "Watch never gets logging UI on the iPhone."

## Locked decisions inherited from the spec

- **Anonymized data only.** All screenshots use the §5.2 stand-in regimen (Med A–E, Ingredient A/B). No real medication names, diagnoses, or identifying info. The App Store does not need Geoff's prescription list.
- **No "writes to Health" claim.** Copy and the privacy label reflect read-only import: `NSHealthUpdateUsageDescription` stays **absent**; `NSHealthShareUsageDescription` is present with read-only language.
- **No iPhone-logging copy.** The description must not suggest logging from the phone (hard CLAUDE.md rule). The phone is setup + history + PDF export only.
- **6.9" iPhone + 46mm watch** are the primary screenshot sizes (the CLAUDE.md simulators map to these). 6.7" is optional, flagged only if clipping appears.
- **W-2 (mid-hold) must be a live capture** (XCUITest or simulator slow-motion), not a fabricated SwiftUI Preview — the App Store review team rejects fake screenshot states. A clearly-labeled Preview shim is a documented fallback only.
- Status bar overridden to 9:41 AM for every screenshot; copy character limits enforced (subtitle ≤30, promo ≤170, keywords ≤100, description ≤4000).

## Child issues

- [ ] **Issue: regimen seed + watch screenshots (W-1…W-5)** — define/seed the §5.2 anonymized regimen, write the §5.3 capture runbook into `Submission/screenshot-script.md`, and capture the five watch screenshots (single-pill card, mid-hold ring, success state, PRN totals, safety warning). Owns the shared seed definition the other children reference.
- [ ] **Issue: iPhone screenshots (I-1…I-4) + marketing copy deck** — capture the four iPhone screenshots (regimen list, history heatmap, day drill-down, PDF share sheet) and write `Submission/marketing-copy.md` verbatim from §5.4, with character-limit checks and the watch-first / read-only-Health copy guardrails.
- [ ] **Issue: privacy nutrition label audit** — line-by-line audit of `Submission/privacy-nutrition.md` and `PillBreakfast/Info.plist` against the shipped codebase: confirm `NSHealthUpdateUsageDescription` absent, `NSHealthShareUsageDescription` present with read-only language, MetricKit-only Diagnostics row, Tracking = No. Produce the PR "Anonymization audit" section content.

## Acceptance for the epic

- Nine screenshot files in `Submission/screenshots/` with the `W-N_*` / `I-N_*` naming, all anonymized, all 9:41 status bar, watch at 396×484pt @2x, iPhone at full res; W-2 shows the hold ring at an obvious 30–70% mid-progress state.
- `Submission/marketing-copy.md` populated with all §5.4 fields, within every character limit, with no read-Health-write claim and no iPhone-logging implication.
- `Submission/privacy-nutrition.md` confirmed accurate (or corrected); Info.plist HealthKit keys verified; the anonymization audit (med-name stand-ins, the `NSHealthShareUsageDescription` string, no-new-SDK confirmation) is in the PR body.
- `pre-commit run --all-files` clean; existing tests pass (pure asset + content; no code change).

## Out of scope (for this epic)

- App Preview videos (v1.1).
- iPad screenshots and any non-en-US localization.
- Writing new code to support capture — all surfaces must already exist from Phases 1–8.
- A HealthKit-import screenshot (I-5) — omitted for v1; the fresh sim has no Health data to show.

---

## Sequencing notes

- Parent of this epic in the phase hierarchy is **#10** (Phase 9 — Hardening & Submission).
- **#61 must merge before this epic** — screenshots are captured with the real icon on the home screen / watch grid.
- All three children depend on the **§5.2 anonymized regimen seed**, which is defined in the watch-screenshots child; the iPhone and privacy children consume it. The privacy-audit child can otherwise run in parallel with the two capture children — it blocks the submission checklist but not capture.
- Soak test **#66** follows this epic (soak findings may surface copy corrections back into `marketing-copy.md`).
