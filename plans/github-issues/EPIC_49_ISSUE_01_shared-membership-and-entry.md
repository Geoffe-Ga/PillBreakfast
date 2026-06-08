## Role

You are a senior watchOS engineer skeletonizing the data path for the real complication: wiring the `Shared/` models and `PendingQueueSelector` into the `WatchAppWidgets` target, enriching `PendingDoseEntry` with its display helpers, and standing up the read-only `ModelContainer` plumbing — without yet reading any rows.

## Goal

Add the `Shared/` files the extension needs to its target membership, extend `PendingDoseEntry` with `displayText` and `hasPending`, and add a private static `makeContext()` that opens a read-only `ModelContainer` against the App Group store. The provider still returns `pendingCount: nil` (renders `"--"`), but now compiles against the shared schema and opens its own container — proving the cross-process store access works before any query lands.

## Context

- **Parent epic:** #49
- **Predecessor:** #48 (widget extension stub — `WatchAppWidgets` target, stub `PendingDoseTimelineProvider`, stub circular complication exist).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-49_three-complication-families.md` §5.1 (entry helpers), §5.2 (`makeContext`), §5.6 (Shared module membership), §5.7 (concurrency).
- **Files involved:**
  - `WatchAppWidgets/PendingDoseTimelineProvider.swift` — extend `PendingDoseEntry`; add `makeContext()`.
  - `PillBreakfast.xcodeproj` — add `Shared/` files to the `WatchAppWidgets` target: `Shared/Models/{Medication,DoseEvent,Ingredient,MedicationComponent,ScheduledDose,SnoozeRecord,PillMeal,Enums,LoggedIngredientAmount}.swift`, `Shared/Persistence/PersistenceController.swift`, `Shared/Queue/PendingQueueSelector.swift`, `Shared/Persistence/IngredientLibrarySeeder.swift` (compiled in transitively — must NOT be executed by the extension).
- **Prior decisions (locked):**
  - The extension opens its OWN `ModelContainer` via `makeContext()` — never `PersistenceController.shared`, which would trigger `IngredientLibrarySeeder.seedIfNeeded` (a write) in a read-only process.
  - `makeContext()` uses `ModelConfiguration(url: PersistenceController.appGroupStoreURL, isStoredInMemoryOnly: false)` and `ModelContainer(for: PersistenceController.schema, configurations:)`.
  - `displayText`: `nil` → `"--"`, `0` → `"✓"`, positive → the digit string. `hasPending`: `(pendingCount ?? 0) > 0`.

## Output Format

A single PR containing:

- [ ] `PendingDoseEntry` gains `var displayText: String` and `var hasPending: Bool` (computed, in an extension).
- [ ] `PendingDoseTimelineProvider.makeContext()` — private static, opens the read-only container against the App Group store URL + schema.
- [ ] The listed `Shared/` files are added to the `WatchAppWidgets` target membership (verified by the extension building against `Medication`, `ScheduledDose`, `PendingQueueSelector`, `PersistenceController`).
- [ ] The provider still returns `pendingCount: nil` in all three callbacks (no row reads yet) — the complication still renders `"--"`.
- [ ] Tests: `displayText` asserts `nil`→`"--"`, `0`→`"✓"`, `3`→`"3"`; `hasPending` asserts `nil`→`false`, `0`→`false`, `1`→`true`.

## Examples

```swift
extension PendingDoseEntry {
    var displayText: String {
        guard let count = pendingCount else { return "--" }
        return count == 0 ? "✓" : "\(count)"
    }
    var hasPending: Bool { (pendingCount ?? 0) > 0 }
}
```

## Constraints

**Scope fence:** Target membership + entry helpers + `makeContext()` only. **No** row reads, **no** real timeline construction (that is the core child #02), **no** new families or deep-link routing (edges child #03). Do NOT call `PersistenceController.shared` or `IngredientLibrarySeeder` from the extension.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The complication still appears on the watch face and renders `"--"`; the watch app and extension still build and run on the paired simulator. Nothing regresses — this PR only adds the scaffolding the next child consumes.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #49`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-7-widgets`, `watch`, `concurrency`
