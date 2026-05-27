# EPIC 10 — Phase 9: Hardening & TestFlight Submission

## Epic Summary

The v1 feature set is complete; this epic gets PillBreakfast onto TestFlight (or the App Store, if Geoff prefers) with the polish a senior-track release expects. App icons, screenshots, marketing copy, HealthKit privacy nutrition labels, crash reporting, mutation-tested critical paths (dose logging, running-total computation, ceiling enforcement), and a 5-day soak test on real hardware. Implements SPEC §10 Phase 9 (lines 503-513) and the Phase 9 stretch skill from §11.

## Scope

**In scope:**

- App icons (1024x1024 master plus all watchOS and iOS derivative sizes).
- Screenshots for the App Store / TestFlight listing on all required device sizes.
- Marketing copy: short description, full description, keywords, what's new.
- Privacy nutrition labels declaring HealthKit medications usage (read-only), no analytics, no third-party SDKs unless we add one for crash reporting.
- **Crash reporting:** chosen mechanism filed as an `architectural-decisions`-style trade-off in the skeleton issue (Apple's MetricKit / XCDiagnostics vs. Crashlytics vs. Sentry). Default recommendation: MetricKit + on-device logs synced to iCloud user-private container; no third-party SDK unless real signal proves it's worth the privacy nutrition delta.
- **Mutation-tested critical paths** per SPEC §11 Phase 9 skill callout: dose logging (`DoseEvent` creation + ingredient snapshot), `totalToday(ingredient:)` and `lastDoseTime(ingredient:)` query helpers, `violationsIfTaken(_:quantity:at:)`. Use Muter (or equivalent Swift mutation tester); target mutation score >= 85% on those three modules. (Geoff has opinions here already; lean on them.)
- **5-day soak test on real hardware:** install on a paired iPhone + Apple Watch, dogfood the real regimen, capture any crash or unexpected behavior in a soak log. Surface the log as a "soak diary" markdown file under `plans/`.
- TestFlight build configuration, version + build number scheme, archive script.

**Out of scope:**

- Any new v1 feature work. This is purely hardening.
- SPEC §12 future work items (EPIC 11).

## Critical Architecture (carry into every child issue)

- **No bypasses for "TestFlight is on Friday."** This is exactly when max-quality-no-shortcuts matters most. A `try?` swallowed under deadline pressure is the bug that ships.
- **Privacy nutrition labels must match reality.** If we add a third-party crash reporter, we must declare what it collects. Default to MetricKit precisely to keep the nutrition label clean.
- **Mutation testing targets the ingredient safety logic specifically.** This is the function that prevents a Tylenol + Excedrin overdose. A green test suite that a mutation tester can blow holes in is not a real safety net.

## Success Criteria

The epic is done when:

- [ ] All required icon sizes are present and pass `xcodebuild`'s asset catalog validation.
- [ ] App Store / TestFlight listing fields are complete with screenshots that show real (anonymized) regimen data.
- [ ] Privacy nutrition labels reflect actual data collection; no overclaims, no underclaims.
- [ ] Mutation score >= 85% on dose logging, ingredient queries, and `violationsIfTaken`. Reproducible via a `scripts/mutate.sh` script.
- [ ] A TestFlight build is uploaded and a one-week soak diary captures no critical bugs.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #60 — Skeleton: Add a `Submission/` folder containing the asset checklist, screenshot script, and a soak diary template — wired but with empty content (EPIC_10_ISSUE_01).
- [ ] #61 — App icons + asset catalog validation across all required watchOS and iOS sizes (EPIC_10_ISSUE_02).
- [ ] #62 — Screenshots + marketing copy for the TestFlight / App Store listing (EPIC_10_ISSUE_03).
- [ ] #63 — Crash reporting decision documented as an `architectural-decisions` trade-off, default MetricKit implemented (EPIC_10_ISSUE_04).
- [ ] #64 — Privacy nutrition labels matching real data collection (EPIC_10_ISSUE_05).
- [ ] #65 — Mutation testing harness via `scripts/mutate.sh` targeting the three critical modules with score >= 85% (EPIC_10_ISSUE_06).
- [ ] #66 — 5-day soak test on real hardware + soak diary capture (EPIC_10_ISSUE_07).

## Sequencing Notes

- **Depends on:** EPIC 09 (full v1 feature set must be in place).
- **Unblocks:** TestFlight submission.
- **Parallel-safe:** None — this is the closing gate.

## SPEC Reference

`plans/SPEC.md` §10 Phase 9 (lines 503-513), §11 (Phase 9 skill callout: mutation testing).

## Labels

`epic`, `spec-decomposition`, `phase-9-hardening`, `tracer-code`.
