# Epic — #49: Three complication families reading real data

## Epic Summary

Replace the #48 stub complication with a fully functional one that reads the live pending-dose count from the shared SwiftData store (via the App Group) and renders it across all three watch complication families — `.accessoryCircular`, `.accessoryCorner`, `.accessoryInline` — showing the count or `"✓"` when clear. Tapping any family deep-links into the watch app's tap-through queue (`pillbreakfast://tap-through`), with the watch app's `onOpenURL` handler wired to route it.

## Scope

- Add the required `Shared/` model + queue files to the `WatchAppWidgets` target membership.
- Open a read-only `ModelContainer` per `getTimeline` against `PersistenceController.appGroupStoreURL` + `PersistenceController.schema` (never `PersistenceController.shared` — the extension is a separate process and must not run the ingredient seeder).
- Compute the pending count via `PendingQueueSelector` and build a 24-hour timeline at window-transition boundaries.
- Implement the three family views and register all three families on one `Widget`.
- Declare the `pillbreakfast` URL scheme in the watch app `Info.plist` (`CFBundleURLTypes`) and add an `onOpenURL` handler.

## Success Criteria

- The circular/corner/inline complications all render on a watch face and show the correct live count, `"✓"` when none pending, `"--"` only in placeholder.
- `PendingDoseEntry.displayText` / `.hasPending` behave per the table (`nil`→`"--"`, `0`→`"✓"`, `n`→`"n"`).
- `getTimeline` produces entries at window-transition dates from an in-memory store (unit-tested).
- Tapping any complication opens the watch app and `onOpenURL` does not crash on `pillbreakfast://tap-through`.
- The extension opens the store read-only — zero `context.save()` calls.
- Both watch app and extension build under Swift 6 strict concurrency with zero warnings; `pre-commit run --all-files` clean.

## Child Issues

- [ ] **Skeleton** — `EPIC_49_ISSUE_01_shared-membership-and-entry.md`: add `Shared/` target membership, enrich `PendingDoseEntry` with `displayText`/`hasPending`, add the read-only `makeContext()` helper returning a stubbed nil-count timeline. Demoable: still renders `"--"`, now wired to open its own container without reading rows.
- [ ] **Core** — `EPIC_49_ISSUE_02_real-timeline-provider.md`: replace the provider with the real one — pending-count read via `PendingQueueSelector`, 24h transition-date timeline, `.atEnd` policy, error fallbacks.
- [ ] **Edges** — `EPIC_49_ISSUE_03_three-families-and-deeplink.md`: implement the three family views + router, register all three families, declare the URL scheme, wire `onOpenURL`, snapshot/preview tests.

## Sequencing Notes

Children are strictly ordered: skeleton → core → edges. Each child's Context names its predecessor. The whole epic is a child of phase-epic **#8** (Phase 7 — Widgets) and the successor of **#48** (stub). It precedes **#50** (Smart Stack), which reuses the extension's `Shared/` membership and the deep-link.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-49_three-complication-families.md` (full design). SPEC §7.4 (complication requirement), SPEC §10 Phase 7 gate.

## Labels

`spec-decomposition`, `core`, `phase-7-widgets`, `watch`, `concurrency`
