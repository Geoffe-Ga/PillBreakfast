# Pill Meals — design + decomposition

> The app's name comes from a Say Anything song; "Pill Breakfast" is the literal
> grouping of meds Geoff takes together in the morning. This doc promotes that
> mental model from informal usage into a first-class concept across the data
> model, watch flow, notifications, history, and onboarding.

Drafted 2026-05-31 while PR #185 (visual-polish track) was in review.

---

## 1. Concept

A **Pill Meal** is a named, time-anchored grouping of medications a user takes
together. Examples (from Geoff's regimen):

- **Pill Breakfast** — supplements, vitamins, anti-anxiety PRN, 1 dose Lithium, ~9:30 AM.
- **Pill Dinner** — 2nd dose Lithium + 2 psychiatric meds, evening.

PRN meds for ad-hoc symptoms (heartburn, headache) **do not belong to a meal** —
they live in the existing "Take as-needed" surface. But a PRN that's *routinely*
taken at a meal time (Geoff's anti-anxiety dose at breakfast) **can** be assigned
to a meal; see §6.

## 2. Decisions (locked)

| Decision | Choice | Source |
|---|---|---|
| Confirmation model | Per-dose confirms inside a meal; meal is organizational only. Press-and-hold preserved on individual high-risk meds. | User answer |
| Late-tracking | **No "late" or "missed" categorization.** Target time drives notifications; logged-time is recorded but not labelled. Compliance = count match (`taken-today == scheduled-today`). | User answer |
| Migration | Auto-suggest meals from time clustering on first launch after release; user confirms / edits / skips. | User answer |
| PRN ↔ meal | A PRN med **can also belong to a meal** without losing its as-needed identity. Same ingredient ID, same safety ceilings, just a routine slot. | Inferred from Geoff's "anti-anxiety PRNs in the AM around 9:30" — flag for explicit confirmation in the implementation PR if there's any doubt. |

## 3. Data model (SPEC §5.4 addendum)

Add one new SwiftData entity and one relationship:

```swift
@Model
public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String                  // "Pill Breakfast" — user-supplied
  public var targetHour: Int               // 0…23
  public var targetMinute: Int             // 0…59
  public var sortOrder: Int                // stable display order
  public var createdAt: Date
  // Reverse relationship is `ScheduledDose.pillMeal`.
}
```

`ScheduledDose` gains:

```swift
public var pillMeal: PillMeal?  // nil = ungrouped (legacy + ad-hoc maintenance)
```

**No** "tolerance" or "window" fields. Per the locked decision above, the
notification fires at `targetHour:targetMinute`; logged time is whatever it
ends up being.

**No** denormalized snapshot on `DoseEvent`. The `DoseEvent` already carries
`scheduledFor: Date` — the meal context is recoverable by joining
`ScheduledDose.pillMeal` at display time. (If history queries become hot, we
can revisit.)

### Invariants

- A `ScheduledDose` with `pillMeal != nil` **must** match the meal's
  `targetHour:targetMinute`. Enforced at edit time in the medication form —
  changing the meal's time auto-updates assigned doses.
- A meal with zero assigned doses is allowed (the user might be setting it up);
  it just doesn't fire notifications.
- PRN-kind medications can have `ScheduledDose` entries assigned to a meal.
  Their PRN ceiling/interval logic is unchanged — the meal slot is just a
  routine occurrence.

## 4. iPhone UX

### 4.1 Regimen tab — new "Pill Meals" section

Above the existing Maintenance / PRN sections:

```
PILL MEALS
[ Pill Breakfast            9:30 AM · 5 doses        > ]
[ Pill Dinner               9:00 PM · 3 doses        > ]
[ + Add a pill meal                                    ]

MAINTENANCE
[ Lithium                  1 daily dose             ! > ]   ← unchanged
...
```

Tapping a meal row pushes a `PillMealEditorView`:
- Name field (`.never` autocapitalization, sentence-case canonical).
- Time picker (`DatePicker(.hourAndMinute)`).
- Assigned doses list — tap to add/remove. Adding shows the maintenance + PRN
  medications, each with a checkbox per scheduled dose that fits the meal's
  time.
- Delete (only when no assignments remain — same deletion-blocked-while-referenced
  pattern we use for ingredients).

### 4.2 Medication editor — meal assignment

`ScheduleRowEditor` gets a new field per row: "Belongs to: [None / Pill Breakfast / Pill Dinner]"
as a Picker. Selecting a meal auto-fills the row's `hour` / `minute` from
the meal and disables direct edit of those fields (changing time is done from
the meal editor).

### 4.3 Empty state on Regimen tab

If no meals are configured but maintenance meds exist, the Regimen tab shows
a banner above the Maintenance section:

> **Set up a Pill Breakfast** — Group meds you take together so the watch
> notification reads "Pill Breakfast" instead of "Pills · 4 to take." [Set up →]

## 5. Watch UX

### 5.1 Notifications

`NotificationScheduler` groups by `PillMeal` first, falling back to
`TimeSlot(hour, minute)` for ungrouped doses (so existing behavior survives).

- **Title** changes from "Pills · N to take" to the meal name when one applies:
  `Pill Breakfast`.
- **Body** stays the formatted med-name list ("Aspirin · Lithium · +2 more").
- Ungrouped scheduled doses keep the existing title.

### 5.2 Tap-through queue

Per-dose confirm cards are unchanged. The card gains a small header line above
the medication name showing meal context:

```
       Pill Breakfast · 2 of 5            ← captionFont, secondary
       Lithium 300mg                       ← displayFont (hero)
       300mg · 1 tablet                    ← dosageFont
       [ Hold to confirm ]                 ← unchanged for high-risk
```

After the **last** dose in a meal logs:

- Show a brief micro-state: "Pill Breakfast logged ✓" with `Motion.dramatic`
  reveal (same shape as `QueueSuccessView`, but tied to one meal completing
  rather than the whole pending set draining).
- If more pending doses exist (e.g., user delayed the meal and now the next
  meal's notifications have fired too), advance to the next meal's first card.
- If no more pending, the existing `QueueSuccessView` ("All pills logged") fires.

### 5.3 Mid-meal skip / cancel behaviour

If the user dismisses the queue mid-meal, the remaining doses stay pending
(matches current behaviour). The next queue open resumes from the next
unlogged dose — meal grouping is recovered from `ScheduledDose.pillMeal`.

## 6. PRN coexistence

Per the locked decision, a PRN med can have a `ScheduledDose` assigned to a
meal. The implementation:

- The meal's tap-through shows the PRN like any other dose card.
- Logging it inserts a `DoseEvent` with `status: .taken` against the PRN
  medication — the existing PRN ceiling/interval logic applies.
- The PRN tab still shows the medication's running total for the day,
  independent of whether the meal-routine dose has been taken yet.
- Taking the PRN *ad-hoc* later in the day (outside the meal) is unchanged —
  the user opens the PRN section and logs it.

**Edge case**: if the meal-routine PRN is logged via the meal flow AND the
user separately logs another ad-hoc dose later, the PRN's daily count reflects
both — the safety logic doesn't care whether a dose came from a meal slot.

## 7. History

### 7.1 Heatmap

No change. The heatmap counts `DoseEvent`s per day; meal grouping is a display
concern, not a count concern.

### 7.2 Day drill-down

The events list groups by meal:

```
PILL BREAKFAST  ·  fired 9:30 AM           ← section header
  9:42  · Lithium 300mg     · Taken          ← actual logged time
  9:43  · Vitamin D         · Taken
  9:44  · Anti-anxiety PRN  · Taken
  9:44  · B-Complex         · Taken
  9:45  · Magnesium         · Taken

PILL DINNER  ·  fired 9:00 PM
  9:18  · Lithium 300mg     · Taken
  9:19  · Lamictal          · Taken
  9:20  · Sertraline        · Taken

AS-NEEDED
  2:14 PM · Famotidine 20mg  · Taken
```

### 7.3 Compliance signal

A small footer under the heatmap: **"23 of 24 doses taken yesterday"** — count
match, no "late" framing. If `taken-today == scheduled-today`, the compliance
line reads "All doses taken." This is the safety-honest framing Geoff asked for.

## 8. Migration / onboarding

### 8.1 Existing installs

On first launch after the release containing meals:

1. `PillMealOnboardingService` clusters every `ScheduledDose` by
   `(hour, minute)` rounded to the nearest 30 minutes.
2. Each cluster with ≥ 2 doses becomes a suggested meal.
3. A one-time sheet shows the suggestions:

```
We found 2 pill groups in your regimen. Name them?

Suggested Pill Meal · 9:30 AM         Vitamin D · Lithium · B12 · Magnesium
[ Name: ________________________ ]    [ Skip ]  [ Save ]

Suggested Pill Meal · 9:00 PM         Lithium · Lamictal · Sertraline
[ Name: ________________________ ]    [ Skip ]  [ Save ]
```

4. Saving creates the `PillMeal` and assigns the cluster's `ScheduledDose`s.
5. A `UserPreferences.pillMealsOnboarded: Bool` flag prevents the sheet from
   re-firing.

### 8.2 New installs

No auto-suggestion (no doses to cluster yet). The empty-state banner on the
Regimen tab (§4.3) is the entry point.

### 8.3 New-medication auto-suggest (every add path)

Whenever a user finishes adding a medication — manual `AddMedicationView`,
HealthKit `ConfirmComponentsView`, or the search-miss create from the
ingredient picker — the save path runs a suggestion check before dismissing:

1. For each scheduled dose on the new med, find existing meals whose target
   time is within 30 min.
2. If exactly one meal matches, the dismiss screen surfaces an inline prompt:

   > **Add to Pill Breakfast?** This dose is at 9:30 AM. _[ Add ] [ Not now ]_

3. If multiple meals match (rare but possible for a med with multiple doses
   per day), show a quick picker:

   > **Add to a Pill Meal?** _[ Pill Breakfast · Pill Dinner · Not now ]_

4. If no meal matches but the user has ≥ 1 meal configured, offer
   "Create new Pill Meal at 9:30 AM" as a one-tap shortcut into the meal editor.

5. If no meals exist yet, no prompt — the empty-state banner on Regimen tab
   (§4.3) is the entry point until the user has at least one meal.

The prompt is non-blocking; "Not now" dismisses to the regimen list and the
med is just ungrouped. Mirrors the duplicate-name guard pattern from #156:
the system surfaces what it knows, the user decides.

### 8.4 HealthKit import flow specifics

Health import lands multiple meds at once. After `ConfirmComponentsView`
saves, the same auto-suggest fires per imported med — but bundled into one
sheet step so the user isn't tapping through N prompts:

> **Add to Pill Meals?**
>
> - Vitamin D (9:00 AM) → _[ Pill Breakfast ▾ ]_
> - Lithium (9:00 AM) → _[ Pill Breakfast ▾ ]_
> - Sertraline (9:00 PM) → _[ Pill Dinner ▾ ]_
>
> _[ Skip all ]  [ Save ]_

## 9. Implementation decomposition

Suggested issue sequence — each ≤ 1 PR:

1. **feat(model): PillMeal entity + ScheduledDose.pillMeal relationship**
   Schema bump. No UI yet. Tests pin the relationship round-trip and the
   "PillMeal time changes propagate to assigned ScheduledDoses" invariant.

2. **feat(notifications): meal-aware notification grouping**
   `NotificationScheduler` groups by `PillMeal` first, falls back to
   `TimeSlot`. Title becomes the meal name. Tests pin both branches.

3. **feat(regimen): PillMeal editor + Regimen tab Pill Meals section**
   `PillMealEditorView`, the meal row, the "+ Add" sheet. Medication editor
   gets the per-row "Belongs to" picker.

4. **feat(watch): meal context + per-meal success state in tap-through queue**
   Card header shows "Pill Breakfast · 2 of 5". Meal-complete micro-state
   between meals. `QueueSuccessView` stays the all-clear state.

5. **feat(history): per-meal grouping on drill-down + compliance footer**
   Day drill-down sections by meal; "N of M doses taken" count match line.

6. **feat(onboarding): PillMealOnboardingService + first-launch suggestion sheet**
   Cluster, propose, accept. `UserPreferences.pillMealsOnboarded` flag.

7. **feat(regimen): auto-suggest "Add to Pill Meal?" on every med-add path**
   Manual `AddMedicationView` save, search-miss create, and HealthKit
   `ConfirmComponentsView` all run the suggestion check and surface the
   inline prompt described in §8.3. HealthKit gets the bundled multi-med
   variant from §8.4.

## 10. Out of scope (for the first decomposition)

- **Multiple notifications per meal** (e.g., 5-min reminder before, or
  escalating reminders for missed meals). The "no late" decision means there's
  nothing to escalate to.
- **Meal-level statistics** ("Your Pill Breakfast streak: 14 days"). Compliance
  is at the dose level for v1.
- **Cross-device meal editing** (creating a meal from the watch). v1 is
  iPhone-only editing; watch is read/log only, matching the existing tap-through
  contract.
- **Smart Stack widget for the next meal**. Widget work is its own phase (#48–#52).
