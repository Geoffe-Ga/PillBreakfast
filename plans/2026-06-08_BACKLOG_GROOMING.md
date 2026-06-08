# Backlog Grooming — 2026-06-08

Groom-gate pass at `total_completed = 90` (every 10 merges).

## PRs analyzed (last 12 merged)

#260–#269 (Phase 7 widgets/complications), #271 (#225 privacy audit), #272 (#121 snooze-default rename), #273 (#142 DoseEvent.medicationID denormalization).

## Issues closed

All three PRs from this groom window auto-closed their issues (#225, #121, #142). Additionally closed three **fully-complete sub-epics** whose children were all merged:

- **#49** — Three complication families. Children #214 (PR #262), #215 (PR #263), #216 (PR #264) all merged.
- **#50** — Smart Stack widget. Children #217 (PR #265), #218 (PR #266) all merged.
- **#51** — LogNextDoseIntent. Children #219 (PR #267), #220 (PR #269) all merged.

## Issues updated

- **#8 (Phase 7 epic)** — progress comment: all child issues (#48–#52) merged; implementation complete. Kept open as the Phase-7 **on-hardware QA anchor** (complications render on a real watch face; pending count updates within ~1 min) to be verified during the Phase 9 TestFlight soak (#66). No implementation work remains.

## Gaps / new issues

None. All session work was issue-tracked; follow-ups (#268, #270) and deferrals (#226–#228 Muter, #221–#224 icons/screenshots, #211–#213 snapshot infra, #66 soak) were already filed with `needs-spec`/`future-work`.

## Backlog health

- Pickable `spec-decomposition` issues remaining: **#199, #203** (PillMeal bounds validation + sortOrder tail-append). Everything else open is `future-work` (v1+ scope) or `needs-spec` (blocked on by-hand work).
- Open epics: phase epics #1–#10 (#8 annotated this pass), #11 (future-work placeholders), #31/#61/#62/#65 (deferred-children), #67–#71 (future-work), #188 (Pill Meals).
