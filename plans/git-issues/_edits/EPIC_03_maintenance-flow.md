# EPIC 03 — Phase 2: Maintenance Flow End-to-End

## Epic Summary

Geoff's real morning regimen works end-to-end: he adds his maintenance meds on the iPhone, the watch shows the right tap-through queue at 8:00 AM, single-tap confirmations log doses locally on the watch, and those doses sync back to the iPhone for history. Notifications fire at the scheduled times — basic fixed schedule for now, no snooze. Implements SPEC §10 Phase 2 (lines 420-430) and the maintenance slices of §6.1, §7.1, §7.2, and §8.1.

This is the first epic where the system delivers actual product value: a watch-first medication tracker that logs maintenance doses with one tap.

## Scope

**In scope:**

- **iPhone Regimen tab (§6.1, maintenance path only):** list view grouped by Maintenance / PRN, swipe-to-archive (soft delete, preserves history), add/edit form for a maintenance medication including name, form, single-ingredient component (mg per unit), `ScheduledDose` rows. PRN configuration UI is stubbed (a "PRN configured here in EPIC 05" empty state is fine).
- **Watch root view (§7.1):** "Right Now" pending queue (within +/- 60 min of a scheduled time, not yet taken) or "all caught up" state with next upcoming time.
- **Watch tap-through queue (§7.2):** one pill per screen, medication name, dosage and pill count, **single-tap Mark Taken**. High-risk press-and-hold is *not* in scope yet (EPIC 04 replaces the stub).
- **Local notifications (§8.1, basic):** one `UNCalendarNotificationTrigger` per `ScheduledDose`, scheduled on the **watch** directly so it works when the phone is off. Notification body lists first two medication names plus "+N more" per §8.2. Custom actions are stubbed (open app only); the snooze action lands in EPIC 06.
- **Full notification rebuild on regimen edit** — never a diff. Cancel all and re-add. This is the convention from CLAUDE.md.
- **Reverse sync of `DoseEvent`s:** watch -> iPhone via `WCSession.transferFile` (a small JSON file per batch, or `transferUserInfo` for a single event), per SPEC §10 Phase 2 and §4. iPhone merges into its SwiftData store keyed by `DoseEvent.id`.
- Unit tests for the queue selection logic (which doses are pending at a given clock time) and for the rebuild-from-empty notification scheduler.

**Out of scope:**

- Press-and-hold gesture and Liquid Glass styling pass (EPIC 04).
- PRN section, quantity picker, ingredient totals, safety warnings (EPIC 05).
- Snooze-until-time and the snooze notification action (EPIC 06).
- HealthKit import (EPIC 07).
- Complications and Smart Stack widget (EPIC 08).
- Calendar heatmap and PDF export (EPIC 09).

## Critical Architecture (carry into every child issue)

- **iPhone never gets logging UI.** No "quick log" button, no "take pills now" prompt. The phone is for setup and review. CLAUDE.md is explicit about this. (SPEC §6 "Hard rule".)
- **Regimen edits trigger a full notification rebuild**, not a diff. CLAUDE.md + SPEC §8.1.
- **Notifications are scheduled on the watch.** They must continue to fire when the iPhone is off. Do not schedule them on the iPhone and rely on Apple to forward.
- **`DoseEvent.ingredientAmounts` is filled at log time on the watch**, denormalized from the medication's current components. EPIC 02 set up the snapshot type; this epic actually writes it.

## Success Criteria

The epic is done when:

- [ ] On the iPhone, the user can add, edit, and archive a maintenance medication; the watch reflects changes within 5 seconds.
- [ ] At a scheduled time, the watch shows the correct pending queue and a local notification fires (verified on the simulator pair).
- [ ] Single-tap Mark Taken writes a `DoseEvent` to the watch's SwiftData store and the iPhone receives it within 30 seconds (next `WCSession` reachability window is acceptable).
- [ ] Editing the regimen on iPhone causes all pending notifications to be cancelled and re-scheduled fresh on the watch.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #21 — Skeleton: iPhone Regimen tab list view + watch root "Right Now" view with stub data wired to the SwiftData store (EPIC_03_ISSUE_01).
- [ ] #22 — iPhone add/edit/archive form for a maintenance medication, persisted to SwiftData (EPIC_03_ISSUE_02).
- [ ] #23 — Watch tap-through queue with single-tap Mark Taken writing `DoseEvent`s (EPIC_03_ISSUE_03).
- [ ] #24 — Local notification scheduler on the watch with full-rebuild semantics on regimen change (EPIC_03_ISSUE_04).
- [ ] #25 — Reverse sync of `DoseEvent`s from watch to iPhone via `WCSession.transferFile` (EPIC_03_ISSUE_05).
- [ ] #26 — Pending-queue selection logic with timezone and "already taken today" edge cases + unit tests (EPIC_03_ISSUE_06).

## Sequencing Notes

- **Blocks:** EPIC 04 (which replaces the single-tap confirm with press-and-hold for high-risk meds), EPIC 06 (which adds snooze to the notification surface this epic builds).
- **Depends on:** EPIC 02 (data model + sync).
- **Unblocks:** EPIC 04, EPIC 05, EPIC 06, EPIC 09 (history needs `DoseEvent`s flowing).
- **Parallel-safe:** None during the sequence.

## SPEC Reference

`plans/SPEC.md` §6.1 (iPhone Regimen tab, maintenance subset), §7.1 (watch root view), §7.2 (tap-through queue, single-tap path only), §8.1-8.2 (notification scheduling & content, snooze excluded), §10 Phase 2 (lines 420-430).

## Labels

`epic`, `spec-decomposition`, `phase-2-maintenance`, `tracer-code`.
