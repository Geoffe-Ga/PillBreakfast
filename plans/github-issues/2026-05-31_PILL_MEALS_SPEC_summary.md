# Pill Meals — SPEC summary

> Full spec: `plans/2026-05-31_PILL_MEALS.md`.

A **Pill Meal** is a named, time-anchored grouping of medications the user takes together (Geoff's "Pill Breakfast" and "Pill Dinner"). Promotes the app's namesake concept into a first-class entity across the data model, notifications, watch tap-through, history, and onboarding.

## Locked decisions

- **Confirmation model**: per-dose confirms inside a meal; meal is organizational only. Press-and-hold preserved on high-risk meds.
- **No "late" / "missed" categorization**. Target time drives notifications; logged time is recorded but not labelled. Compliance = `taken-today == scheduled-today`.
- **Migration**: auto-suggest meals from existing schedule time clustering on first launch; user confirms / edits / skips.
- **PRN ↔ meal**: a PRN med can belong to a meal without losing its as-needed identity.

## Data shape

```swift
@Model public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String
  public var targetHour: Int           // 0…23
  public var targetMinute: Int         // 0…59
  public var sortOrder: Int
  public var createdAt: Date
}
// ScheduledDose gains: public var pillMeal: PillMeal?
```

No tolerance fields. No denormalized snapshot on `DoseEvent` — meal context joins through `ScheduledDose.pillMeal` at display time.

## Surface impact

- **iPhone Regimen tab**: new "Pill Meals" section above Maintenance / PRN.
- **Medication editor**: per-schedule-row meal picker.
- **Watch tap-through**: card header shows "Pill Breakfast · 2 of 5"; per-meal success micro-state.
- **Notifications**: title becomes the meal name when one applies.
- **History drill-down**: events grouped by meal; compliance footer.
- **Onboarding**: first-launch suggestion sheet + per-add-path inline prompt.

## Decomposition (filed as 3 epics, 9 issues)

| Epic | Issues |
|---|---|
| **Foundation** (data + iPhone CRUD + notifications + watch context) | skeleton → editor → notifications → watch |
| **History & compliance** | skeleton → per-meal grouping + count footer |
| **Onboarding & auto-suggest** | skeleton (clustering + flag) → first-launch sheet → per-add-path prompt |

Each epic's first issue is a skeleton that wires the surfaces with stubs — the app stays demoable end-to-end at every step.
