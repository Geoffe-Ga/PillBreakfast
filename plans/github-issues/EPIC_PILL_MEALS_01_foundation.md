# Epic — Pill Meals foundation

## Outcome

The user can create a Pill Meal on the iPhone, assign scheduled doses to it, receive a notification titled with the meal name, and see the meal context on the watch tap-through card. The watch and iPhone agree on which meal a dose belongs to via the SwiftData relationship; legacy ungrouped doses keep working unchanged.

## Spec sections

- `plans/2026-05-31_PILL_MEALS.md` §§ 3 (data model), 4 (iPhone UX), 5 (watch UX), 6 (PRN coexistence)
- `plans/SPEC.md` §§ 5.2 (schema), 6.1 (Regimen tab), 7.2 (tap-through), 8 (notifications)

## Locked decisions inherited from the spec

- Per-dose confirms inside a meal (meal is organizational; press-and-hold preserved on high-risk meds).
- No "late" / "missed" tracking. `PillMeal` carries `targetHour` / `targetMinute` only.
- No denormalized meal snapshot on `DoseEvent` — display layer joins through `ScheduledDose.pillMeal`.
- PRN-kind medications can have `ScheduledDose`s assigned to a meal without losing their as-needed identity.

## Child issues

Sequenced so the skeleton lands first and every subsequent issue keeps the app demoable.

- [ ] **Issue: skeleton** — `PillMeal` model + `ScheduledDose.pillMeal` relationship + empty "Pill Meals" section on the Regimen tab + meals `@Query` stub. Tests pin the round-trip and the empty-state render.
- [ ] **Issue: editor + assignment** — `PillMealEditorView` for create/edit/delete; per-row meal picker on `ScheduleRowEditor`.
- [ ] **Issue: notifications** — `NotificationScheduler` groups by `PillMeal` first, falls back to `TimeSlot`. Title becomes the meal name when one applies.
- [ ] **Issue: watch tap-through** — card header line "Pill Breakfast · 2 of 5"; per-meal success micro-state between meals; `QueueSuccessView` stays the all-clear state.

## Acceptance for the epic

- A user can configure a meal on the iPhone, assign two or more existing scheduled doses to it, and receive a single watch notification titled with the meal name.
- The watch tap-through queue shows the meal context above each card and surfaces a "Pill Breakfast logged ✓" micro-state after the last dose in the meal.
- Legacy ungrouped doses (`pillMeal == nil`) keep firing per-`TimeSlot` notifications and rendering without meal context — no regressions for existing installs.
- All new and existing tests pass; `pre-commit run --all-files` clean.

## Out of scope (for this epic)

- History grouping by meal — that's the History & compliance epic.
- Auto-suggest / first-launch onboarding — that's the Onboarding epic.
- Smart Stack widget surfacing the next meal — tracked under the existing widgets phase (#48–#52).

---

## Child issues (filed)

- [ ] #189 — feat(model): PillMeal entity + ScheduledDose.pillMeal relationship (skeleton)
- [ ] #190 — feat(regimen): PillMealEditorView + per-row meal picker on ScheduleRowEditor
- [ ] #191 — feat(notifications): meal-aware notification grouping in NotificationScheduler
- [ ] #192 — feat(watch): meal context header + per-meal success micro-state in tap-through queue
