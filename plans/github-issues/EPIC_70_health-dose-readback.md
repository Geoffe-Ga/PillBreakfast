# Epic — #70: Health dose readback enrichment

## Epic Summary

Close the dual-logging gap between Apple Health and PillBreakfast. Apple Health can log a medication dose through its own UI; today PillBreakfast has no idea and will still fire its watch prompt for a dose the user already took — inviting a duplicate log on a safety-critical regimen. This epic runs an `HKAnchoredObjectQuery` over `HKMedicationDoseEvent` **on the iPhone only** (the Medications API is iOS-only), matches each `.taken` Health dose to a local `Medication` via `healthKitConceptID` (the one sanctioned join key), and syncs a resolved, day-scoped "already taken in Health" suppression set to the watch over the existing WatchConnectivity regimen channel. The watch then suppresses (or, opt-in, annotates) the matching pending-dose card and `UNCalendarNotificationTrigger`. PillBreakfast still **never** writes to Health — this is strictly read-side enrichment. The symmetric "PillBreakfast logged it, quiet Health's reminder" direction is impossible under the current API and is the domain of #72.

## Scope

- iPhone-only HealthKit access; all readback code lives in the `PillBreakfast` app target (`PillBreakfast/HealthKitImport/`), never `Shared/`. The watch never sees a Health concept token.
- Per-medication **read** authorization for `HKMedicationDoseEvent` (a separate sample type from the Phase 6 medication grant); no write scope is ever requested (none exists).
- Incremental `HKAnchoredObjectQuery` with a durably-persisted `HKQueryAnchor` (App Group), filtered to status `.taken`, off-main-actor handler hopping under Swift 6 strict concurrency.
- Pure `HealthDoseMatcher` + a resolution layer that maps concept tokens → `Medication.healthKitConceptID` → a resolved `(medicationID, hour, minute, day)` DTO.
- Additive `RegimenSnapshot` v5 field carrying the resolved suppression set iPhone → watch via `updateApplicationContext`; re-push on every anchored-query fire and every regimen change.
- Watch-side suppression at the two centralized plug points (`PendingQueueSelector`, `NotificationBootstrap`), with retraction/skip handling that un-suppresses.

## Success Criteria

- iPhone requests per-medication **read** authorization for `HKMedicationDoseEvent`; never write.
- An `HKAnchoredObjectQuery` observes `.taken` dose events; the `HKQueryAnchor` persists across launches in the App Group; each pass processes deltas only.
- Health dose events match local `Medication`s **only** via `healthKitConceptID`; unmatched and manually-added meds are never suppressed (name matching is rejected).
- A resolved, day-scoped suppression set syncs iPhone → watch on the regimen channel (`RegimenSnapshot` v5, additively decodable from v4).
- The watch suppresses the matching pending-dose card and notification for that day; a retracted or `.skipped`/`.missed` Health dose un-suppresses.
- No `DoseEvent` is ever fabricated from a Health dose; PRN totals and the PDF export are unaffected. Declined authorization fails open to normal prompting.
- Both targets build/run on the paired simulator under Swift 6 strict concurrency with zero warnings; `pre-commit run --all-files` clean.

## Child Issues

- [ ] **Skeleton** — `EPIC_70_ISSUE_01_dose-event-read-auth.md`: extend the HealthKit actor with `requestDoseEventReadAuthorization()` for the `HKMedicationDoseEvent` type + iPhone Settings affordance and usage string. Tested via the existing protocol seam (no real `HKHealthStore` in tests). Demoable: Settings shows a "Sync from Apple Health" dose-event auth affordance; nothing yet observes or suppresses.
- [ ] **Core** — `EPIC_70_ISSUE_02_anchored-query-and-anchor-store.md`: `HealthDoseReadbackService` actor with the long-lived `HKAnchoredObjectQuery` (status `.taken`, date-bounded initial batch) and `HealthReadbackAnchorStore` (App Group-backed `HKQueryAnchor` persistence), off-main-actor `@Sendable` handler hopping. Emits raw `HealthTakenSlot`s. No matching/sync yet.
- [ ] **Core** — `EPIC_70_ISSUE_03_matcher-and-resolution.md`: pure `HealthDoseMatcher` (samples/deletions → `HealthTakenSlot`s / retractions, concept-token round-trip vs. `HealthKitImportService.draft(from:)`) + the resolution layer mapping tokens → `Medication.healthKitConceptID` → `HealthSuppressedSlotDTO`, with dedup and unmatched-drop. Heavily unit-tested.
- [ ] **Core** — `EPIC_70_ISSUE_04_regimen-snapshot-v5-wc-push.md`: additive `RegimenSnapshot` v5 `healthSuppressedSlots` field + `HealthSuppressedSlotDTO`; encode/decode (v4 decodes with `[]` default); wire the readback fire and regimen change to recompute and re-push via `WatchConnectivityCoordinator`. iPhone → watch only.
- [ ] **Edges** — `EPIC_70_ISSUE_05_watch-consumption-and-retraction.md`: `PendingQueueSelector` excludes suppressed slots for `now`'s day; `NotificationBootstrap.refresh` omits suppressed triggers in the full rebuild; retraction/skip un-suppresses and re-surfaces; day-scope filters stale next-day suppressions; declined-auth fails open. End-to-end manual verification on a real device.

## Sequencing Notes

Children are strictly ordered: skeleton → core (02 → 03 → 04) → edges. Each child's Context names its predecessor. The whole epic is a child of phase-epic **#11** (Future Work, SPEC §12.4). It is complementary to **#72** (Apple Feedback write-access advocacy): #70 makes the best of read-only today; #72 petitions for the write that would obviate the symmetric direction. Annotate-mode + Settings toggle (hint #6) and a background-refresh trigger via `HKObserverQuery`/`enableBackgroundDelivery` (hint #7) are deliberately **deferred** — both are gated on dogfooding (latency/UX confusion) and are out of scope until that data exists; file them as follow-ups only if needed.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` (full design). SPEC §3.2/§3.3 (HealthKit read-only & iOS-only; read-back enrichment clause), §5.2/§5.3 (denormalized snapshot, never fabricate history), §8 (notifications full rebuild), §12.4 (this charter).

## Labels

`spec-decomposition`, `future-work`, `core`, `notifications`, `concurrency`
