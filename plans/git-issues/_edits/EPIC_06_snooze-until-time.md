# EPIC 06 — Phase 5: Snooze-Until-Time

## Epic Summary

Replace iOS's fixed-duration snooze with the flagship "Snooze until 10:17 PM" interaction. Tapping the **Snooze...** action on a notification opens a watch `SnoozeView` with `DatePicker(.hourAndMinute)`; the user picks a wall-clock time, the pending re-fire is cancelled, and a fresh `UNCalendarNotificationTrigger` is scheduled for the chosen time. Post-midnight snoozes re-fire the next morning. A soft "you've snoozed this 3 times - skip instead?" warning appears on the fourth. Implements SPEC §10 Phase 5 (lines 458-468) and the full §8.3 flow.

## Scope

**In scope:**

- A custom `UNNotificationAction` named `SNOOZE_UNTIL_TIME` registered with the `.foreground` option, attached to the maintenance-dose notification category from EPIC 03.
- A `SnoozeView` SwiftUI screen on the watch with a `DatePicker(displayedComponents: .hourAndMinute)` styled in Liquid Glass per EPIC 04's design system. "Done" button confirms.
- Snooze scheduling logic in `Shared/Notifications/`: cancels the current notification's pending re-fire by identifier, schedules a new `UNCalendarNotificationTrigger` for the selected wall-clock time, repeats=false so it's a one-shot.
- **Post-midnight handling:** if the chosen time is earlier than `now`, schedule for tomorrow at that time. Unit-tested.
- **Snooze counter on the originating `DoseEvent`** — increment a new `snoozeCount: Int` field (additive schema migration; default 0) every time a snooze action fires for the dose's scheduled occurrence. On the fourth (`snoozeCount >= 3` going into the action), surface a soft "You've snoozed this 3 times — skip instead?" interstitial with Snooze again / Skip / Take now actions.
- Default snooze offset setting on iPhone (SPEC §6.3) — controls only the initial picker position, not a fixed snooze duration.
- Unit tests for: cancel-then-schedule round-trip, post-midnight rollover, third-snooze counter behavior.

**Out of scope:**

- HealthKit import (EPIC 07).
- Widget / complication surfaces (EPIC 08).
- Any change to the press-and-hold gesture (EPIC 04).

## Critical Architecture (carry into every child issue)

- **Snooze is snooze-until-time, not fixed-duration.** CLAUDE.md and SPEC §8.3 are explicit. A "snooze 10 minutes" implementation would regress the flagship UX. The default-offset setting only positions the picker; it does not skip the picker.
- **Snooze re-fire is a one-shot `UNCalendarNotificationTrigger`, not a repeating one.** The original daily schedule continues unchanged; the snooze adds a single extra fire for today's occurrence.
- **Regimen edits still trigger a full notification rebuild** (CLAUDE.md). The snooze logic must integrate cleanly with that rebuild — pending snoozes should be re-derived from `DoseEvent.snoozeCount` after a rebuild, or cleared (decide as part of issue 02; my recommendation is "snoozes survive the rebuild because they refer to today's occurrence, but a snooze whose target time has passed is simply dropped").
- **Schema migration:** the `snoozeCount: Int` addition to `DoseEvent` (or a parallel "scheduled occurrence" model — see open question below) is additive and must follow SwiftData lightweight-migration rules.

## Success Criteria

The epic is done when:

- [ ] Tapping **Snooze...** on a notification opens `SnoozeView`, picking 10:17 PM and tapping Done causes the notification to re-fire at 10:17 PM (verified on the simulator pair).
- [ ] Snoozing past midnight (e.g. picking 6:30 AM at 11:50 PM) causes the notification to re-fire at 6:30 AM the next day.
- [ ] After three consecutive snoozes of the same scheduled occurrence, the fourth Snooze... tap shows the soft warning interstitial.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #38 — Skeleton: Register the `SNOOZE_UNTIL_TIME` action and add a stub `SnoozeView` that closes without rescheduling (EPIC_06_ISSUE_01).
- [ ] #39 — Implement the cancel-then-schedule round-trip in `Shared/Notifications/` with unit tests, including post-midnight rollover (EPIC_06_ISSUE_02).
- [ ] #40 — Wire `SnoozeView` (`DatePicker(.hourAndMinute)` + Done) to the snooze scheduler with Liquid Glass styling (EPIC_06_ISSUE_03).
- [ ] #41 — Add `DoseEvent.snoozeCount` with additive SwiftData migration and the fourth-snooze soft warning interstitial (EPIC_06_ISSUE_04).
- [ ] #42 — iPhone Settings entry for default snooze picker position (SPEC §6.3) (EPIC_06_ISSUE_05).

## Sequencing Notes

- **Depends on:** EPIC 03 (notification scheduling), EPIC 04 (design system, gesture conventions on the warning interstitial).
- **Unblocks:** Nothing strictly, but the flagship UX feels incomplete without it.
- **Parallel-safe:** EPIC 05 (PRN safety) is on a different surface and can ship in parallel.

## SPEC Reference

`plans/SPEC.md` §2.2 (Snooze journey), §8.3 (Snooze-Until-Time flow with edge case, lines 362-372), §10 Phase 5 (lines 458-468), §11 (Phase 5 skill callout: BGTaskScheduler).

## Labels

`epic`, `spec-decomposition`, `phase-5-snooze`, `tracer-code`.
