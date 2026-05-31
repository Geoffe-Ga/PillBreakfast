## Role

You are a senior Swift engineer wiring the `PillMeal` skeleton across the SwiftData store, the iPhone Regimen tab, and the watch read path. **Skeleton only** — no editor UI, no notifications wiring, no watch card header changes. The app builds, runs, and behaves identically to today for existing users.

## Goal

- `PillMeal` SwiftData model exists, conforms to the existing `PersistenceController.schema`, and round-trips through SwiftData (create, fetch, delete).
- `ScheduledDose.pillMeal: PillMeal?` relationship is wired. Existing rows roundtrip with `nil`.
- The iPhone Regimen tab renders an empty "Pill Meals" section above Maintenance / PRN. Empty-state copy: "No pill meals yet — group meds you take together to get a single notification at that time."
- `PendingQueueSelector` and `NotificationScheduler` continue to behave exactly as they do today (meal grouping is the next issue's job).

## Context

- **Parent epic:** 186
- **Spec sections:** `plans/2026-05-31_PILL_MEALS.md` §§ 3 (data model), 4.1 (Regimen tab placement)
- **Files involved:**
  - `Shared/Models/PillMeal.swift` (new) — `@Model` per the spec.
  - `Shared/Models/ScheduledDose.swift` — add the `pillMeal` relationship.
  - `Shared/Persistence/PersistenceController.swift` — add `PillMeal.self` to the schema.
  - `PillBreakfast/RegimenTab/RegimenListView.swift` — new empty section above Maintenance.
  - `PillBreakfastTests/Models/PillMealTests.swift` (new) — round-trip + relationship tests.
- **Prior decisions (locked):**
  - Field shape per `plans/2026-05-31_PILL_MEALS.md` §3. **No** tolerance / window fields.
  - `pillMeal: PillMeal?` is `nil` for legacy rows; the editor in the next issue is what sets it.
  - No denormalized snapshot on `DoseEvent`. Display joins through the relationship.

## Output Format

A single PR containing:

- [ ] `PillMeal` model + `ScheduledDose.pillMeal` relationship + schema registration.
- [ ] Empty "Pill Meals" section on `RegimenListView` above the existing Maintenance / PRN sections, using `PillEmptyStateView` for the empty copy.
- [ ] Tests:
  - `PillMealRoundTripsThroughSwiftData` — insert / fetch / delete cycle.
  - `ScheduledDosePillMealRelationshipIsOptional` — assigning `nil` is valid.
  - `ExistingScheduledDoseFetchesReturnNilPillMeal` — legacy-row compat.
- [ ] No notification scheduler / watch tap-through changes. No editor UI.

## Examples

```swift
// Shared/Models/PillMeal.swift
@Model
public final class PillMeal {
  @Attribute(.unique) public var id: UUID
  public var name: String
  public var targetHour: Int
  public var targetMinute: Int
  public var sortOrder: Int
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    name: String,
    targetHour: Int,
    targetMinute: Int,
    sortOrder: Int = 0,
    createdAt: Date = .now
  ) { ... }
}
```

## Constraints

**Scope fence:** Skeleton only. **No** editor UI, **no** notification grouping, **no** watch card header changes — those are the next three issues.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** App builds and runs on the paired-sim pair. Existing tap-through, notifications, regimen, and history flows behave identically. The new "Pill Meals" section renders empty.

## Done-Done

- [ ] All new and existing tests pass on both iOS and watchOS schemes.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Closes #<this issue>` and `Refs #186`.

## Labels

`spec-decomposition`, `tracer-code`, `core`, `phase-4-prn-safety`
