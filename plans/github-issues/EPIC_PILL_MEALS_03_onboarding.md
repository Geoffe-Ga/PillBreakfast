# Epic — Pill Meals onboarding & auto-suggest

## Outcome

The user discovers Pill Meals naturally — on first launch after the feature ships, the app proposes meals by clustering their existing schedule and lets them accept / edit / skip. After that, every med-add path (manual, search-miss inline create, HealthKit import) surfaces an inline "Add to Pill Meal?" prompt when a time match exists.

## Spec sections

- `plans/2026-05-31_PILL_MEALS.md` § 8 (migration / onboarding)
- `plans/SPEC.md` § 6.1 (Regimen tab), § 6.1 — HealthKit import callout

## Locked decisions inherited from the spec

- **Auto-suggest, not auto-create.** The first-launch sheet proposes meals; nothing persists without the user tapping Save per row.
- **Time-cluster window: 30 min** for "this dose looks like it belongs to that meal."
- The `UserPreferences.pillMealsOnboarded: Bool` flag prevents the first-launch sheet from firing twice.
- HealthKit import shows a bundled multi-med variant in one sheet step (§8.4), not a per-med prompt cascade.

## Child issues

- [ ] **Issue: skeleton** — `PillMealOnboardingService` clustering helper (`@MainActor`) + `UserPreferences.pillMealsOnboarded` flag + a stub first-launch sheet that prints the proposed clusters without persisting. Tests pin the clustering helper end-to-end.
- [ ] **Issue: first-launch sheet** — wire the suggestion sheet into the iPhone Regimen tab. User can name / save / skip per row; the flag flips on dismiss.
- [ ] **Issue: per-add-path auto-suggest** — add the inline "Add to Pill Meal?" prompt to `AddMedicationView`, `NewIngredientView`'s save-completion, and `ConfirmComponentsView`'s post-import step. HealthKit gets the bundled multi-med variant.

## Acceptance for the epic

- A user with existing scheduled doses sees the first-launch sheet exactly once, with one suggestion row per ≥ 2-dose time cluster.
- After the foundation epic ships, the auto-suggest prompt fires whenever a user adds a med whose schedule lands within 30 min of an existing meal's target time.
- A user with no existing meals doesn't see any auto-suggest prompt — only the empty-state banner from the foundation epic.
- All new and existing tests pass; `pre-commit run --all-files` clean.

## Out of scope (for this epic)

- "Smart" suggestions beyond simple time clustering (e.g., grouping by medication class).
- Re-firing the first-launch sheet if a user adds many meds later — they use the per-add-path prompt instead.
- Watch-side onboarding — meal editing is iPhone-only by spec.

---

## Child issues (filed)

- [ ] #195 — feat(onboarding): PillMealOnboardingService + pillMealsOnboarded flag + stub sheet
- [ ] #196 — feat(onboarding): first-launch suggestion sheet with name/save/skip per row
- [ ] #197 — feat(regimen): auto-suggest "Add to Pill Meal?" on every med-add path
