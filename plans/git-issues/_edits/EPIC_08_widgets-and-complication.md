# EPIC 08 — Phase 7: Widgets & Complication

## Epic Summary

Geoff can log doses from his watch face without opening the app. A watch complication (circular, corner, inline) shows pending dose count or "✓" when clear and taps deep-link into the tap-through queue. A Smart Stack widget surfaces 15 minutes before each scheduled dose with a single-tap log driven by `AppIntent`. Background refresh keeps both surfaces current. Implements SPEC §10 Phase 7 (lines 480-489), §7.4 (complication), and §7.5 (Smart Stack widget).

## Scope

**In scope:**

- **Watch complication** in three families per SPEC §7.4: `.accessoryCircular`, `.accessoryCorner`, `.accessoryInline`. Each shows the count of pending doses for the current +/- 60-minute window, or `"✓"` when clear. Liquid Glass background per watchOS 26 guidelines.
- **Tap target:** the complication's `deepLinkURL` or `WidgetURL` opens the watch app directly to the tap-through queue.
- **Smart Stack widget** surfacing 15 min before each scheduled time, per SPEC §7.5. The widget shows the next medication and a single-tap "Mark Taken" affordance.
- **`LogNextDoseIntent: AppIntent`** in a `Shared/Intents/` target (or a per-target intents module — settle in the skeleton issue) that logs the next pending dose. Honors the high-risk rule from EPIC 04: a high-risk med's widget surface shows "Open to confirm" instead of a one-tap shortcut and links into the press-and-hold screen. **No one-tap path may bypass press-and-hold for high-risk meds.**
- **Background refresh:** `WKApplicationRefreshBackgroundTask` (watchOS) / `BGAppRefreshTask` (iOS extension) wakes periodically to update the complication's pending count after dose changes. Use `WidgetCenter.shared.reloadAllTimelines()` after any `DoseEvent` write on either device.
- Snapshot tests for the three complication families against known regimen fixtures.
- Manual checklist in PR template: add complication to a watch face on the simulator, log a dose, verify the count decrements.

**Out of scope:**

- History / PDF visuals (EPIC 09).
- App Store assets (EPIC 10).

## Critical Architecture (carry into every child issue)

- **High-risk meds never get a one-tap widget surface.** This preserves the safety guarantee from EPIC 04. The widget can advertise that a high-risk dose is pending; tapping must open the app to the press-and-hold screen.
- **The iPhone still does not get logging UI.** That includes iPhone widgets — no iOS home-screen widget that logs a dose. Pending-count display on iPhone is acceptable (it's review, not logging).
- **Complication updates are eventual, not real-time.** Apple budgets are tight; the implementation must batch reloads and not call `WidgetCenter.reloadAllTimelines()` on every minor write.
- **Liquid Glass extends to widgets.** Use the design-system module from EPIC 04. Color discipline still holds: monochromatic baseline, amber only on high-risk.

## Success Criteria

The epic is done when:

- [ ] All three complication families render correctly on a watch face and tap-launch into the app.
- [ ] The pending count on the complication updates within 1 minute of logging or skipping a dose (within Apple's complication budget — exact latency is not under our control, but the reload must be triggered).
- [ ] The Smart Stack widget surfaces 15 minutes before a scheduled dose and a single tap logs a non-high-risk dose without opening the app.
- [ ] Tapping the Smart Stack widget for a high-risk dose opens the app to the press-and-hold screen; it does not log directly.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #48 — Skeleton: Add the watch widget extension target with a single complication family rendering a stub pending count (EPIC_08_ISSUE_01).
- [ ] #49 — Implement all three complication families (circular, corner, inline) with deep-link to the tap-through queue (EPIC_08_ISSUE_02).
- [ ] #50 — Smart Stack widget that surfaces 15 min before a scheduled dose with Liquid Glass styling (EPIC_08_ISSUE_03).
- [ ] #51 — `LogNextDoseIntent: AppIntent` wired to single-tap widget logging, with the high-risk "open to confirm" fallback (EPIC_08_ISSUE_04).
- [ ] #52 — Background refresh on both targets calling `WidgetCenter.shared.reloadAllTimelines()` after dose writes (EPIC_08_ISSUE_05).

## Sequencing Notes

- **Depends on:** EPIC 03 (logging machinery + `DoseEvent` flow), EPIC 04 (design system + high-risk gesture rules).
- **Unblocks:** Nothing strictly.
- **Parallel-safe:** EPIC 07 and EPIC 09 are on independent surfaces.

## SPEC Reference

`plans/SPEC.md` §7.4 (complication), §7.5 (Smart Stack widget), §10 Phase 7 (lines 480-489), §11 (Phase 7 skill callout: `AppIntent`).

## Labels

`epic`, `spec-decomposition`, `phase-7-widgets`, `tracer-code`.
