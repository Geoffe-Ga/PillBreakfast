# PillBreakfast — SPEC Summary (Decomposition Index)

> Source: `plans/SPEC.md` (v1.0, 2026-05-15). This is a one-page restatement so each issue can ground itself without re-reading the whole document. The SPEC remains authoritative; this file is a navigation aid.

## Vision

A watch-first medication tracker for watchOS 26 + iOS 26. Geoff takes ~12 pills/day across maintenance and PRN regimens, including safety-critical doses (lithium). Product thesis: **glance, tap, done** on the wrist — zero-ambiguity tap-through logging. The iPhone is setup + history only; it never shows "take pills now" prompts.

## Locked Tech Stack (SPEC §4, CLAUDE.md)

| Layer | Choice |
| --- | --- |
| OS targets | watchOS 26, iOS 26 |
| Language | Swift 6 with strict concurrency (`Sendable`, actor isolation) |
| UI | SwiftUI, `@Observable` (not `ObservableObject`) |
| Persistence | SwiftData, shared via App Group |
| Phone <-> watch sync | WatchConnectivity (`WCSession`): `updateApplicationContext` for regimen, file transfer for history |
| Notifications | UserNotifications, scheduled on the watch directly |
| Design | Liquid Glass (`.glassEffect()` / Material APIs) |
| Build/CI | Xcode 17 + Xcode Cloud, existing GitHub Actions in `.github/workflows/` |

## Four Load-Bearing Constraints

1. **HealthKit Medications is read-only and iOS-only.** Third-party apps cannot write to Apple Health Medications (Apple DTS confirmed). `HKMedicationDoseEvent` / `HKUserAnnotatedMedication` exist only on iOS/iPadOS/visionOS, never watchOS. Health is a **one-way import source for onboarding only**; PillBreakfast owns its own SwiftData store as the source of truth. (SPEC §3, CLAUDE.md.)
2. **`DoseEvent` ingredient amounts are deliberately denormalized.** `LoggedIngredientAmount.totalMg = quantity * component.dosagePerUnitMg` is captured *at log time*. Running totals must stay fast on the watch, and editing a product's components later must not retroactively rewrite history. (SPEC §5.3.)
3. **Watch never gets logging UI on the iPhone.** No "quick log" buttons on the phone — it dilutes the product thesis. Logging happens on the wrist; the phone is for setup and review only. (SPEC §6, CLAUDE.md.)
4. **High-risk meds use press-and-hold confirmation; color is reserved for them.** Single-tap is fine for vitamins. Anything with `isHighRisk == true` (any ingredient flagged high-risk, e.g. lithium) requires the press-and-hold gesture with a visible Liquid Glass progress ring. Baseline UI is monochromatic glass; warm amber accent appears only on high-risk confirmations. (SPEC §7.2, §9, CLAUDE.md.)

Two corollary rules worth pinning:

- **Regimen edits trigger a full notification rebuild**, not a diff. Simpler and avoids stale `UNCalendarNotificationTrigger`s. (CLAUDE.md.)
- **Snooze is snooze-until-time**, not fixed-duration. Custom `UNNotificationAction` opens a watch `DatePicker(.hourAndMinute)`; soft warning on the fourth consecutive snooze. (SPEC §8.3.)

## Phased Plan (the spine of the decomposition)

Per SPEC §10, work follows tracer-code methodology: wire the skeleton end-to-end first, then iteratively replace stubs. **At every phase boundary the app must build and run on a paired iPhone + watch simulator.**

1. **Phase 0 — Skeleton.** Paired iOS + watchOS Xcode targets, App-Group SwiftData container stub, `WCSession` handshake logging. Both apps show "Hello PillBreakfast." → **EPIC 01.**
2. **Phase 1 — Data Model & WC Sync Tracer.** All `@Model` classes from §5; iPhone seeds one hardcoded medication and pushes it to the watch via `updateApplicationContext`. → **EPIC 02.**
3. **Phase 2 — Maintenance Flow.** iPhone Regimen tab (add/edit/archive), watch tap-through queue for the current window, basic notification scheduling, reverse sync of `DoseEvent`s. → **EPIC 03.**
4. **Phase 3 — High-Risk Confirmation + Liquid Glass First Pass.** Press-and-hold gesture with progress ring, `.glassEffect()` throughout primary screens, color reserved for high-risk only, success-state shimmer. → **EPIC 04.**
5. **Phase 4 — PRN Flow + Ingredient-Aware Running Totals.** PRN section on watch, quantity picker, `totalToday(ingredient:)` / `lastDoseTime(ingredient:)` queries, `violationsIfTaken` safety check, soft warning interstitial that names the *ingredient*. → **EPIC 05.**
6. **Phase 5 — Snooze-Until-Time.** Custom `UNNotificationAction`, `SnoozeView` with `DatePicker(.hourAndMinute)`, reschedule logic with post-midnight handling, three-snooze soft warning. → **EPIC 06.**
7. **Phase 6 — HealthKit Import.** iPhone HealthKit per-medication read authorization, query `HKUserAnnotatedMedication`, map to PillBreakfast `Medication` (preserve `healthKitConceptID`), dedupe on re-import. → **EPIC 07.**
8. **Phase 7 — Widgets & Complication.** Watch complication (circular, corner, inline), Smart Stack widget that surfaces 15 min before scheduled doses, single-tap log via `AppIntent`, background refresh. → **EPIC 08.**
9. **Phase 8 — History, Export, Polish.** iPhone calendar heatmap, per-day drill-down, PDF export via `PDFKit`, share sheet, accessibility audit. → **EPIC 09.**
10. **Phase 9 — Hardening & Submission Prep.** App icons, screenshots, privacy nutrition labels, crash reporting, mutation-tested critical paths, 5-day soak. → **EPIC 10.**

A final **EPIC 11 — Future Work (Placeholders Only)** holds SPEC §12 items (RxImage pill thumbnails, iCloud sync, caregiver mode, Health readback enrichment, Action Button, Apple feedback request). These are not ready to ship and are filed with the `needs-spec` label as parking-lot issues.

## Where the canonical files live

- SPEC: `plans/SPEC.md` (do not duplicate).
- Decomposition source-of-truth: this directory, `plans/git-issues/`.
- Phase plan files (forthcoming, one per epic): `plans/YYYY-MM-DD_PHASE_N_<NAME>.md`.
- Filing plan (the shell-script-shaped runbook the parent agent will execute): `plans/git-issues/FILING_PLAN.md`.
