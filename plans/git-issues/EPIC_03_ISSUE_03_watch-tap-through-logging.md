## Role

You are a senior watchOS engineer building the core tap-through queue. You understand the watch app lifecycle, SwiftData writes from a `@MainActor` `View`, and the "one pill per screen" UX from SPEC §7.2.

## Goal

Implement the watch tap-through queue: one pill per screen, single-tap **Mark Taken**. Tapping writes a `DoseEvent` to the watch's local SwiftData store with a complete `ingredientAmounts` snapshot, then advances to the next pending pill or to a "All morning pills logged ✓" success state. **Single-tap only in this issue** — high-risk press-and-hold lands in EPIC 04. (We deliberately leave the single-tap behavior in place for high-risk meds during this issue; EPIC 04 will swap it out. The stub Lithium does not get tapped in this issue's manual test.)

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_03_ISSUE_02_NUMBER (so non-high-risk meds exist to test against; "Vitamin D" from that issue's manual checklist is the working example).
- **SPEC section:** `plans/SPEC.md` §2.1 (Morning Maintenance, lines 23-30), §7.2 (Tap-Through Queue, lines 311-321).
- **Files involved:**
  - `WatchApp Watch App/TapThroughQueue/TapThroughQueueView.swift` — host view that pages through pending doses.
  - `WatchApp Watch App/TapThroughQueue/MarkTakenView.swift` — single-pill screen (extending the EPIC_03_ISSUE_01 placeholder).
  - `WatchApp Watch App/TapThroughQueue/QueueSuccessView.swift` — "All pills logged" success state (no shimmer yet — that's EPIC 04).
  - `Shared/Logging/DoseEventWriter.swift` — pure function `func writeDoseEvent(for medication: Medication, scheduledFor: Date?, quantity: Int, at now: Date, in context: ModelContext) throws -> DoseEvent` that builds `ingredientAmounts` from the medication's current `components` and persists.
  - `PillBreakfastTests/Logging/DoseEventWriterTests.swift` — covers single-ingredient and combo snapshot construction.
- **Prior decisions (locked):**
  - **`DoseEvent.ingredientAmounts` is filled at log time**, denormalized from the medication's current components. SPEC §5.3, CLAUDE.md.
  - **`loggedOn = .watch`** for any `DoseEvent` written here.
  - The "Skip" / "Snooze until..." secondary actions are SPEC §7.2 features — Skip lands in this issue (writes `DoseStatus.skipped`), Snooze waits for EPIC 06.
  - On the watch's success view, navigate back to `RightNowView` after a 1.5s delay; the user can always re-open the app from the watch face.
- **State of the world:** EPIC_03_ISSUE_02 has landed. The iPhone can add a maintenance medication; the watch sees it. There is no `DoseEvent` writing yet.

## Output Format

A single PR containing:

- [ ] `TapThroughQueueView` that paginates through `[PendingDose]` from `PendingQueueSelector` and shows one `MarkTakenView` per dose.
- [ ] `MarkTakenView` with: medication name (large), `"<dosagePerUnitMg>mg · <quantity> tablet(s)"`, an optional color dot if `Medication.colorHex` is set, a primary "Mark Taken" button. Long-press on the Digital Crown menu yields "Skip" (writes `DoseStatus.skipped`); "Snooze until..." is shown as disabled with a "available in EPIC 06" hint, or omitted entirely (engineer's choice — call it out in the PR).
- [ ] `DoseEventWriter.writeDoseEvent(...)` builds an immutable `ingredientAmounts` snapshot from `medication.components` at write time and persists. Tested with single-ingredient and combo medications.
- [ ] Animated paginator between screens (default SwiftUI page-style is fine; Liquid Glass shimmer lands in EPIC 04).
- [ ] On the iPhone side, no UI changes; only the EPIC_03_ISSUE_05 reverse-sync issue will surface watch-written `DoseEvent`s there.

## Examples

`DoseEventWriter` core:

```swift
@MainActor
public enum DoseEventWriter {
    public static func writeDoseEvent(
        for medication: Medication,
        scheduledFor: Date?,
        quantity: Int,
        status: DoseStatus,
        at now: Date,
        in context: ModelContext
    ) throws -> DoseEvent {
        let amounts: [LoggedIngredientAmount] = medication.components.compactMap { c in
            guard let ingredient = c.ingredient else { return nil }
            return LoggedIngredientAmount(
                ingredientID: ingredient.id,
                ingredientName: ingredient.name,
                totalMg: Double(quantity) * c.dosagePerUnitMg
            )
        }
        let event = DoseEvent(
            id: UUID(),
            medication: medication,
            scheduledFor: scheduledFor,
            takenAt: now,
            quantity: quantity,
            status: status,
            loggedOn: .watch,
            ingredientAmounts: amounts
        )
        context.insert(event)
        try context.save()
        return event
    }
}
```

Test:

```swift
func testWritingComboProductSnapsAllIngredientAmounts() throws {
    let context = try makeInMemoryContext()
    let acetaminophen = Ingredient(name: "Acetaminophen", ...)
    let aspirin = Ingredient(name: "Aspirin", ...)
    let caffeine = Ingredient(name: "Caffeine", ...)
    let excedrin = Medication(displayName: "Excedrin Extra Strength", ...)
    excedrin.components = [
        MedicationComponent(ingredient: acetaminophen, dosagePerUnitMg: 250),
        MedicationComponent(ingredient: aspirin, dosagePerUnitMg: 250),
        MedicationComponent(ingredient: caffeine, dosagePerUnitMg: 65),
    ]
    let event = try DoseEventWriter.writeDoseEvent(
        for: excedrin, scheduledFor: nil, quantity: 2, status: .taken, at: .now, in: context
    )
    XCTAssertEqual(event.ingredientAmounts.count, 3)
    XCTAssertEqual(event.ingredientAmounts.first { $0.ingredientName == "Acetaminophen" }?.totalMg, 500)
    XCTAssertEqual(event.ingredientAmounts.first { $0.ingredientName == "Caffeine" }?.totalMg, 130)
}
```

Manual checklist:

1. iPhone: add "Vitamin D 2000mg" at 8:00 AM daily.
2. Watch: set simulator time to 8:00 AM. `RightNowView` shows the tap-through queue.
3. Tap Mark Taken. The success view appears, then the watch returns to `RightNowView` showing "All caught up."
4. Inspect the watch's SwiftData via a debug button or breakpoint: one `DoseEvent` with `loggedOn = .watch` and a single `LoggedIngredientAmount` for cholecalciferol at 2000mg.

## Constraints

**Scope fence:** No press-and-hold gesture — EPIC 04. No notifications — EPIC_03_ISSUE_04. No reverse sync — EPIC_03_ISSUE_05. No PRN quantity picker — EPIC 05.

**Snapshot at log time is non-negotiable.** Do not query `medication.components` on read for the running totals or PDF later. The snapshot in `ingredientAmounts` is what guarantees historical accuracy if the user edits the product's components.

**`loggedOn = .watch` always.** This is the audit field that lets EPIC 09's PDF distinguish watch-logged from iPhone-logged events (the latter should not exist for `DoseEvent`s, but the field exists for completeness).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets build; iPhone Regimen tab works; watch can now log a non-high-risk dose end-to-end. The iPhone does not yet see the new `DoseEvent` — EPIC_03_ISSUE_05.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist completes.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-2-maintenance`.
