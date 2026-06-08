# Epic — #71: Apple Watch Ultra Action Button binding ("Log Next Pill")

## Epic Summary

Bind the Apple Watch Ultra's physical **Action Button** to "log the next pending pill," so a maintenance dose can be confirmed with one tactile, eyes-free press without raising the wrist into the app. The implementation is a thin layer over machinery that already exists: the widget's `LogNextDoseIntent` (EPIC 08 ISSUE 04) already encodes the exact contract — **including the non-negotiable safety rule that high-risk meds are never one-press logged**. For a high-risk next dose the Action Button must *open the press-and-hold confirm screen* instead of logging directly, identical to the Smart Stack widget. The core engineering instruction is to **factor the "next pending dose" decision tree into one place** the widget intent and the Action Button intent both call, so the two surfaces can never drift apart on the safety rule. Then expose a runnable `AppIntent` the system can offer as an Action Button option, route the high-risk path into the existing `MarkTakenView` press-and-hold screen, add eyes-free haptic feedback, and handle Ultra-only availability gracefully on non-Ultra hardware.

## Scope

- A single shared decision helper the widget intent and the Action Button intent both call: `none → caught-up feedback`, `high-risk → route to press-and-hold confirm (NEVER auto-log)`, `not high-risk → DoseEventWriter.write(.taken) + transfer + reload timelines + haptic`.
- A `LogNextPillIntent` `AppIntent` exposed via `AppShortcutsProvider` so the system can present it as an Action Button option; reuses `PendingQueueSelector` + `DoseEventWriter` — no parallel logging logic.
- High-risk routing reusing the `NotificationActionRouter` pattern: an `@MainActor @Observable` `ActionButtonRouter` the root view observes to present the existing high-risk `MarkTakenView`.
- Eyes-free haptic vocabulary (logged / caught-up / failed) + post-log `WidgetCenter.shared.reloadAllTimelines()`.
- Ultra-only availability: the intent ships always and is harmless via Siri/Shortcuts on non-Ultra; any binding-guidance UI is advisory and gated where the hardware exists. No crash, no dead UI on Series watches.

## Success Criteria

- An `AppIntent` logs the **next pending maintenance dose** via `DoseEventWriter.writeDoseEvent` (`loggedOn: .watch`), reusing `PendingQueueSelector` — no parallel logging logic.
- For a high-risk next dose the intent **never logs**; it opens the app onto the press-and-hold confirm screen for that dose (parity with the EPIC 08 widget). Releasing early / backing out logs nothing.
- The non-high-risk log path is shared with (identical to) the widget intent's path.
- After a successful log: dose transferred to iPhone (non-fatal on failure, logged via `os.Logger`), `reloadAllTimelines()` called, confirming haptic played. No pending dose → no-op with distinct feedback; write failure → dose stays pending + failure feedback.
- Non-Ultra hardware: no crash, no dead UI; binding guidance shown only where applicable. No iPhone logging surface introduced; amber stays reserved for the high-risk confirm.
- Both targets build/run on the paired simulator under Swift 6 strict concurrency with zero warnings; `pre-commit run --all-files` clean. The high-risk "must not auto-log" test passes.

## Child Issues

- [ ] **Skeleton** — `EPIC_71_ISSUE_01_shared-log-next-decision-helper.md`: extract/confirm the one `@MainActor` "log next pending dose" decision helper the widget intent and the Action Button intent both call. High-risk branch returns a *route*, not a log; non-high-risk branch is byte-for-byte the widget's write path. Fully unit-tested (this is the load-bearing safety test). Demoable: the widget intent is refactored to call the shared helper with identical behavior; no Action Button surface yet.
- [ ] **Core** — `EPIC_71_ISSUE_02_log-next-pill-intent.md`: `LogNextPillIntent` `AppIntent` + `AppShortcutsProvider` exposure so the system can offer it as an Action Button option. Delegates to the shared helper. Confirm the watchOS 26 binding mechanism against the SDK first. Reachable via Shortcuts on any watch; functional one-press log of a non-high-risk dose.
- [ ] **Core** — `EPIC_71_ISSUE_03_router-haptics-and-ultra-availability.md`: `ActionButtonRouter` (`@MainActor @Observable`, `NotificationActionRouter` pattern) + root-view presentation of the high-risk `MarkTakenView`; double-press debounce; eyes-free haptic vocabulary (logged / caught-up / failed) + post-log `reloadAllTimelines`; Ultra-only Settings hint + non-Ultra no-crash handling.

## Sequencing Notes

Children are strictly ordered: skeleton → core (02 → 03). Each child's Context names its predecessor. The whole epic is a child of phase-epic **#11** (Future Work, SPEC §12.5). It inherits the safety contract from EPIC 04 (press-and-hold high-risk gesture) and EPIC 08 ISSUE 04 (`LogNextDoseIntent` — the widget intent core). The one-press log **must not** auto-log high-risk meds — it opens the press-and-hold confirm, exactly as the widget does. PRN logging, meal logging, and any iPhone Action Button surface are explicit non-goals.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-71_ultra-action-button.md` (full design). SPEC §6 (iPhone never logs), §7.2 (tap-through + press-and-hold), §7.5 (single-tap widget log via `AppIntent`), §11 Phase 7 (`AppIntent` callout), §12.5 (this charter). Inherits `plans/git-issues/EPIC_08_ISSUE_04_log-next-dose-intent.md`.

## Labels

`spec-decomposition`, `future-work`, `core`, `watch`
