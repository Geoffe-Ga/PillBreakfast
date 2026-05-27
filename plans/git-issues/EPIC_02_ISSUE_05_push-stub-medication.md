## Role

You are a senior Apple-platforms engineer pushing the first real product payload across the `WCSession` boundary. You understand `updateApplicationContext`'s "latest wins" semantics and why we use it for regimen sync rather than `sendMessage`.

## Goal

On the iPhone, seed one hardcoded medication ("Stub Lithium 300mg, daily 8am") into the local SwiftData store on first launch, build a `RegimenSnapshot`, and push it to the watch via `WCSession.updateApplicationContext`. On the watch, decode the incoming context, apply it to the local SwiftData store, and render the medication's name in the placeholder `RootView`. Editing the medication's name on the iPhone must cause the new name to appear on the watch within 5 seconds (the SPEC §10 Phase 1 gate).

## Context

- **Parent epic:** #2
- **Predecessor issue(s):** #EPIC_02_ISSUE_04_NUMBER (snapshot DTO + converters must exist).
- **SPEC section:** `plans/SPEC.md` §10 Phase 1 (lines 409-419) — explicit gate: "Edit medication name on iPhone → see updated name on watch within 5 seconds."
- **Files involved:**
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — extend with `pushRegimen(_:)` (iPhone-side) and `receivedApplicationContext(_:)` (watch-side) that decode + apply the snapshot.
  - `iOSApp/Bootstrap/StubMedicationSeeder.swift` (new) — seeds the hardcoded "Stub Lithium" on first launch on iPhone only.
  - `iOSApp/RootView.swift` — replace placeholder with a list showing the iPhone's local medications (so the editing affordance has a UI). Editing is a single `TextField`; full Regimen tab UI is EPIC 03.
  - `WatchApp Watch App/RootView.swift` — replace placeholder with a list showing the watch's local medications received from the snapshot.
- **Prior decisions (locked):**
  - Use `updateApplicationContext` for regimen sync, not `sendMessage` (SPEC §4). It survives the receiver being offline; the latest payload wins.
  - **iPhone-only seed.** The watch must not also seed a stub medication; it receives it via sync.
  - This is intentionally a hardcoded stub. Full add/edit/archive UI is EPIC 03.
- **State of the world:** Full schema, seeded ingredient library, snapshot DTO, `WCSession` activates. No payload has been sent yet.

## Output Format

A single PR containing:

- [ ] `StubMedicationSeeder.seedIfNeeded(context:)` on iPhone — inserts one `Medication` ("Stub Lithium 300mg") with one `MedicationComponent` (Lithium Carbonate as a high-risk Ingredient — seed Lithium specifically since this stub needs a high-risk path; library Ingredients from EPIC_02_ISSUE_03 do not include Lithium) and one `ScheduledDose` (8:00 AM daily, quantity 1). Idempotent.
- [ ] `WatchConnectivityCoordinator.pushRegimen(from: ModelContext)` — encodes a `RegimenSnapshot` and calls `WCSession.default.updateApplicationContext(_:)`.
- [ ] `WatchConnectivityCoordinator.session(_:didReceiveApplicationContext:)` — decodes a `RegimenSnapshot` and applies it to the local SwiftData store.
- [ ] Auto-push on iPhone: whenever the medication is edited (TextField commits), push a fresh snapshot. Simplest implementation is "push on every save"; we can debounce in EPIC 03.
- [ ] iPhone `RootView` shows a `List` of the local medications with an inline `TextField` for `displayName`.
- [ ] Watch `RootView` shows a `List` of the local medications (read-only, since the watch never edits the regimen — CLAUDE.md, SPEC §6).
- [ ] Unit tests where possible (the actual `WCSession` round-trip is best validated manually on the simulator pair, and the issue includes a manual checklist in the PR template).

## Examples

iPhone seed (abridged):

```swift
@MainActor
enum StubMedicationSeeder {
    static let stubID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    static func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Medication>(
            predicate: #Predicate { $0.id == stubID }
        ))
        guard existing.isEmpty else { return }

        let lithium = Ingredient(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Lithium Carbonate",
            aliases: [],
            isHighRisk: true,
            dailyCeilingMg: 2400,
            minIntervalMinutes: 360
        )
        context.insert(lithium)

        let med = Medication(
            id: stubID,
            displayName: "Stub Lithium 300mg",
            unitForm: .tablet,
            kind: .maintenance,
            createdAt: .now,
            prnAvailableQuantities: []
        )
        context.insert(med)

        let component = MedicationComponent(medication: med, ingredient: lithium, dosagePerUnitMg: 300)
        context.insert(component)

        let schedule = ScheduledDose(hour: 8, minute: 0, quantity: 1, daysOfWeek: [], medication: med)
        context.insert(schedule)

        try context.save()
    }
}
```

Watch receives:

```swift
nonisolated public func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
) {
    guard let data = applicationContext["regimen"] as? Data else { return }
    Task { @MainActor in
        do {
            let snapshot = try JSONDecoder().decode(RegimenSnapshot.self, from: data)
            try snapshot.apply(to: PersistenceController.shared.container.mainContext)
            try PersistenceController.shared.container.mainContext.save()
            logger.info("Applied regimen with \(snapshot.medications.count) meds.")
        } catch {
            logger.error("Failed to decode/apply regimen: \(error)")
        }
    }
}
```

Manual checklist (in the PR body):

1. Run paired simulator pair; both apps launch.
2. iPhone shows `[Stub Lithium 300mg]` in its list. Watch shows the same within 5 seconds.
3. Edit iPhone's TextField to `Lithium 450mg`; tap Done. Within 5 seconds, the watch row updates.
4. Force-quit both apps and relaunch. Watch still shows the latest value. (`updateApplicationContext` persists the last context.)

## Constraints

**Scope fence:** Do not build the full Regimen tab UI. Do not handle medication deletion / archiving from the iPhone — EPIC 03. Do not surface PRN configuration. Do not send `DoseEvent`s back to iPhone — EPIC 03's reverse sync. Do not start a snooze flow.

**iPhone never gets logging UI.** The TextField is for editing the regimen, not logging a dose. There is no "Mark Taken" button anywhere on the iPhone, even temporarily. (CLAUDE.md, SPEC §6.)

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** This is the EPIC 02 closing gate. Both targets must build, run, render their lists, and a name edit must propagate within 5 seconds.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist above completes.
- [ ] PR opened with `Refs #2` and `Closes #EPIC_02_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-1-data-model`.
