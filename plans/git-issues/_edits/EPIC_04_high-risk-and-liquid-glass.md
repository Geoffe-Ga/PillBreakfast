# EPIC 04 — Phase 3: High-Risk Confirmation + Liquid Glass First Pass

## Epic Summary

Lithium feels safe to take. The app stops looking like a port of iOS chrome and starts looking like a watchOS 26 native — Liquid Glass surfaces, monochromatic baseline, warm amber appearing only on the press-and-hold confirmation of high-risk meds. Implements SPEC §10 Phase 3 (lines 431-441) and the entire §9 design language plus the high-risk path of §7.2.

## Scope

**In scope:**

- **Press-and-hold gesture** on the watch tap-through screen for any medication whose `isHighRisk` (computed from any ingredient's `isHighRisk` flag) is true. Hold duration tweakable via Settings (SPEC §6.3); default 0.5s per SPEC §2.1. Releases too early -> no log.
- **Liquid Glass progress ring** that fills as the user holds; uses the `.glassEffect()` / Material APIs on watchOS 26. Releases mid-fill animate back to empty.
- **Single-tap path unchanged** for non-high-risk meds (the EPIC 03 implementation stays exactly as-is for those rows). Do not regress vitamins to require a hold.
- **`.glassEffect()` applied throughout the primary watch screens**: root "Right Now" view, tap-through screen, queue advance transitions. iPhone receives the same Material treatment on the Regimen tab list and edit form so the two surfaces feel like one product.
- **Color discipline:** baseline monochromatic glass per SPEC §9. Warm amber appears only on the press-and-hold ring and on the "press-and-hold required" hint. No other color anywhere — vitamins, PRN, history all stay monochromatic.
- **Success-state shimmer animation** at the end of the queue ("All morning pills logged" with glass shimmer).
- **Typography pass:** SF Pro Rounded for medication names, SF Pro Display for dosage figures, per SPEC §9.
- **Settings entry on iPhone** (SPEC §6.3) for the press-and-hold duration; persisted in SwiftData and synced to the watch as part of the regimen snapshot.
- Snapshot tests for the high-risk vs. non-high-risk tap-through screens.
- A manual visual-review checklist embedded in the PR template for the Liquid Glass pass.

**Out of scope:**

- PRN safety warnings (EPIC 05).
- Snooze flow (EPIC 06).
- HealthKit import flow visuals (EPIC 07 inherits the design system).
- Complication and widget visuals (EPIC 08 inherits the design system).
- History and PDF visuals (EPIC 09 inherits the design system).

## Critical Architecture (carry into every child issue)

- **`isHighRisk` is computed on `Medication`** from its ingredients (see EPIC 02). Do not add a stored flag on the product. SPEC §5.3 explains why: "lithium is risky whether it comes as Lithobid or generic carbonate."
- **Color is reserved for high-risk meds.** CLAUDE.md is explicit: "Baseline UI is monochromatic glass. Amber accent appears only on press-and-hold confirmations. Don't decorate other surfaces with color."
- **High-risk = press-and-hold with a visible progress ring.** Single-tap on a high-risk med must never log. There is no "I'm sure, just do it" override on the gesture itself.
- **The iPhone still has no logging UI.** Visual polish on iPhone is for setup/history surfaces only.

## Success Criteria

The epic is done when:

- [ ] Lithium (or any seeded high-risk med) cannot be logged with a single tap on the watch; press-and-hold for the configured duration is required.
- [ ] Releasing the press-and-hold gesture before completion animates the ring back to empty and does not write a `DoseEvent`.
- [ ] A vitamin (non-high-risk) still logs with a single tap and shows no amber accent anywhere.
- [ ] Visual review on a watchOS 26 simulator confirms the primary screens use Liquid Glass backgrounds and the iPhone Regimen tab matches.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #27 — Skeleton: Add a `LiquidGlassTheme` design-system module in `Shared/DesignSystem/` with token APIs (colors, materials, typography) and apply it to the watch root view as a smoke test (EPIC_04_ISSUE_01).
- [ ] #28 — Press-and-hold gesture with progress ring for high-risk meds on the watch tap-through screen (EPIC_04_ISSUE_02).
- [ ] #29 — Apply `.glassEffect()` and Material backgrounds to the watch tap-through queue, success state, and iPhone Regimen tab (EPIC_04_ISSUE_03).
- [ ] #30 — Settings entry on iPhone for press-and-hold duration, persisted and synced to the watch (EPIC_04_ISSUE_04).
- [ ] #31 — Snapshot tests for high-risk vs. non-high-risk tap-through screens, plus a manual visual-review checklist in the PR template (EPIC_04_ISSUE_05).

## Sequencing Notes

- **Blocks:** EPIC 05 (which lands on top of the same tap-through machinery; cleanest to ship the gesture model first).
- **Depends on:** EPIC 03 (single-tap tap-through must exist before we promote it to press-and-hold for the high-risk subset).
- **Unblocks:** EPIC 05, EPIC 06, EPIC 07, EPIC 08, EPIC 09 — all inherit the design system.
- **Parallel-safe:** Most non-UI work in EPIC 06 (notification scheduling rewrite) could overlap with EPIC 04's design-system module.

## SPEC Reference

`plans/SPEC.md` §2.1 (Morning Maintenance journey, press-and-hold), §6.3 (Settings - gesture duration), §7.2 (tap-through high-risk path), §9 (Liquid Glass design language, lines 376-388), §10 Phase 3 (lines 431-441), §11 (Phase 3 skill callout: custom gesture recognizers with haptics).

## Labels

`epic`, `spec-decomposition`, `phase-3-high-risk`, `design-system`, `tracer-code`.
