## Role

You are a senior Swift engineer extending `NotificationScheduler` so the watch's "Pills · N to take" notification becomes "Pill Breakfast" (or whatever the user named the meal) when one applies.

## Goal

`NotificationScheduler.makeRequests(from:)` groups by `PillMeal` first, falling back to the existing `TimeSlot(hour, minute)` grouping for ungrouped doses. The notification title is the meal name; the body is the same med-name list `bodyText(for:)` already produces. Ungrouped doses keep the existing "Pills · N to take" title verbatim.

## Context

- **Parent epic:** 186
- **Predecessor:** the editor issue (user must be able to assign doses to a meal to test this).
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` § 5.1 (notifications)
- **Files involved:**
  - `Shared/Notifications/NotificationScheduler.swift` — extend the grouping pass.
  - `Shared/Sync/RegimenSnapshot.swift` — surface `PillMeal` info on the snapshot so the watch sees the meal name without a relationship traversal.
  - `PillBreakfastTests/Notifications/NotificationSchedulerTests.swift` — extend with meal-aware cases.

## Output Format

A single PR containing:

- [ ] Snapshot DTO gains the meal info (denormalized: meal name + target slot per dose).
- [ ] `NotificationScheduler.makeRequests(from:)` groups by `PillMeal` first, then by `TimeSlot` for ungrouped doses.
- [ ] Title becomes the meal name when one applies; ungrouped fallback uses the existing `"Pills · N to take"` format.
- [ ] `userInfo[medicationNameUserInfoKey]` keeps the existing body string so snooze-rescheduling stays correct.
- [ ] New tests:
  - `mealAssignmentProducesOneRequestTitledWithMealName`
  - `ungroupedDosesStillProduceTheExistingTimeSlotTitle`
  - `mixedRegimenProducesOneMealRequestPlusOneTimeSlotRequest`

## Examples

```swift
// Expected output for a Pill Breakfast at 8:00 AM with Vitamin D and Lithium:
request.content.title == "Pill Breakfast"
request.content.body  == "Vitamin D · Lithium"
// And an ungrouped 2:00 PM Aspirin dose:
otherRequest.content.title == "Pills · 1 to take"
otherRequest.content.body  == "Aspirin"
```

## Constraints

**Scope fence:** Notification grouping only. **No** watch tap-through changes (next issue). **No** UI changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Ungrouped doses on existing installs produce the same notification requests as before — pin this in tests with a fixture that has no meals at all.

## Done-Done

- [ ] All new and existing tests pass on both iOS and watchOS schemes.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #186`.

## Labels

`spec-decomposition`, `core`, `notifications`, `phase-4-prn-safety`
