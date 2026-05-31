# Epic — Pill Meals on History & compliance

## Outcome

The History tab's per-day drill-down groups events by Pill Meal, with a "N of M doses taken" compliance line at the bottom (count match, no late/missed framing). Heatmap behaviour is unchanged — the meal concept is a display affordance in the drill-down, not a query change.

## Spec sections

- `plans/2026-05-31_PILL_MEALS.md` § 7 (history)
- `plans/SPEC.md` § 6.2 (History tab)

## Locked decisions inherited from the spec

- **No "late" or "missed" buckets.** Compliance is a single count: `taken-today / scheduled-today`. If the two match, the footer reads "All doses taken."
- Logged time is preserved in the per-event line (`9:42 · Lithium · Taken`); we do **not** annotate it as on-time or late.
- PRN ad-hoc doses still group under an "As-needed" section, independent of any meal-routine PRN doses.

## Child issues

- [ ] **Issue: skeleton** — drill-down list re-organised into named sections keyed on `pillMeal?.id`; an "As-needed" section catches PRN doses without a meal; compliance footer renders a placeholder ("0 of 0 doses taken") wired to the count helper.
- [ ] **Issue: per-meal grouping + count** — the named sections show the meal name + fired-at target time; the compliance footer reflects the real per-day taken-vs-scheduled count.

## Acceptance for the epic

- On a day with a "Pill Breakfast" meal and three logged doses, the drill-down shows a "PILL BREAKFAST · fired 9:30 AM" section followed by the three events.
- Ungrouped (legacy or PRN) doses appear under "As-needed".
- Compliance footer reads "All doses taken" when count == scheduled, or "N of M doses taken" otherwise — never "missed" or "late".
- Heatmap unchanged. PDF export unchanged for v1.
- All new and existing tests pass; `pre-commit run --all-files` clean.

## Out of scope (for this epic)

- "Streak" / multi-day compliance — count is per-day only.
- Re-styling the heatmap with meal-aware intensity.
- Export-side meal grouping (PDF gets it in a later polish pass if Geoff asks).

---

## Child issues (filed)

- [ ] #193 — feat(history): per-meal grouping skeleton + compliance footer placeholder
- [ ] #194 — feat(history): real per-meal section headers + compliance count footer
