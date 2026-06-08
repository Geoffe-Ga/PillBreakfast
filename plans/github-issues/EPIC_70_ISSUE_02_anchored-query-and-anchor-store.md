## Role

You are a senior iOS / HealthKit + Swift-concurrency engineer building the incremental observation core of Health dose readback: a `HealthDoseReadbackService` actor that runs a long-lived `HKAnchoredObjectQuery` over `.taken` `HKMedicationDoseEvent`s on the iPhone, plus a durable App Group-backed `HealthReadbackAnchorStore` so each pass is a delta, not a full re-scan.

## Goal

Add `HealthDoseReadbackService` (an `actor` owning its own `HKHealthStore`) with an idempotent `startObserving(onDoses:)` that issues a single `HKAnchoredObjectQuery` (predicate = status `.taken`, date-bounded initial batch), persists the returned `HKQueryAnchor` via `HealthReadbackAnchorStore`, and delivers new/changed/deleted samples to a `@Sendable` callback by hopping back onto the actor with `Task { await onDoses(...) }`. This child stops at emitting raw `HealthTakenSlot`s from the handler; matching/resolution is child #03 and the WC sync is #04.

## Context

- **Parent epic:** #70
- **Predecessor:** #70 child #01 (`EPIC_70_ISSUE_01_dose-event-read-auth.md` — the dose-event read authorization + protocol seam).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` §5.1 (component overview), §5.3 (anchored query + concurrency notes), §8 (anchor loss / date-bound initial batch), §10 (anchor persistence round-trip test).
- **Files involved:**
  - `PillBreakfast/HealthKitImport/HealthDoseReadbackService.swift` (new) — the actor (iOS-only target — never `Shared/`).
  - `PillBreakfast/HealthKitImport/HealthReadbackAnchorStore.swift` (new) — App Group-backed `HKQueryAnchor` archive/load (`NSSecureCoding`, same technique as the concept-ID token archiving in `HealthKitImportService.draft(from:)`).
  - the `HealthKitImporting`-style protocol seam — extend so the readback path is exercised with a fake; the real `HKHealthStore`-touching actor is never instantiated in tests.
  - `PillBreakfast/HealthKitImport/HealthKitImportService.swift` — reference for the actor-owned-store + `Mutex`/`Task` hop pattern to mirror.
- **Prior decisions (locked):**
  - HealthKit is **iOS-only**; this actor lives entirely in the `PillBreakfast` app target.
  - Predicate filters to **status `.taken` only** — `.skipped`/`.missed`/`.delayed` are not consumed doses and must never suppress.
  - The handler runs on an arbitrary HealthKit queue: it must be `@Sendable`, must not touch actor state directly, and hops back via `Task { await onDoses(...) }` — exactly as `HealthKitImportService` hops. No `@unchecked Sendable`.
  - `startObserving` is **idempotent**: a second call stops the prior query before issuing a new one so re-auth/foreground can't stack handlers.
  - The anchor persists in the App Group; first run with `nil` anchor returns the full current batch, so the initial query is **date-bounded** (e.g. last 48h) to avoid suppressing doses far in the past.
  - HealthKit errors are **logged via `os.Logger`**, never swallowed by a bare `try?`.

## Output Format

A single PR containing:

- [ ] `HealthDoseReadbackService` actor: owns `HKHealthStore` + the live `HKAnchoredObjectQuery`; `startObserving(onDoses: @escaping @Sendable ([HealthTakenSlot]) async -> Void)` that stops any prior query, loads the anchor, builds the `.taken` + date-bound predicate, executes the query, and sets `updateHandler`.
- [ ] `HealthReadbackAnchorStore`: `loadAnchor() -> HKQueryAnchor?` and `save(_:)` archiving via `NSSecureCoding` into App Group storage.
- [ ] The handler hops to the actor via `Task { await onDoses(...) }`; errors are logged via `os.Logger` (not discarded); new anchors are saved on each fire.
- [ ] `HealthTakenSlot` Sendable value type introduced here if not already present (the matcher in #03 populates it from real samples; this child can emit a minimal mapping or hand raw samples to a thin extraction point — keep the boundary `Sendable`).
- [ ] Protocol seam extended so the readback observation is exercised with a fake; the real actor is never instantiated in tests.
- [ ] Tests: `HealthReadbackAnchorStore` save/load round-trip of an `HKQueryAnchor`; idempotent `startObserving` stops the prior query before issuing a new one (via the seam/fake); the `.taken`+date-bound predicate is constructed as specified.

## Examples

```swift
actor HealthDoseReadbackService {
    private let store = HKHealthStore()
    private let anchorStore: HealthReadbackAnchorStore   // App Group-backed
    private var liveQuery: HKAnchoredObjectQuery?

    /// Idempotent: a second call stops the prior query so re-auth/foreground can't stack handlers.
    func startObserving(onDoses: @escaping @Sendable ([HealthTakenSlot]) async -> Void) {
        if let liveQuery { store.stop(liveQuery) }
        let anchor = anchorStore.loadAnchor()   // nil on first run → date-bounded full batch
        let predicate = HKQuery.predicateForMedicationDoseEvent(withStatus: .taken)
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
            = { [anchorStore] _, samples, deleted, newAnchor, error in
                guard error == nil else { /* os.Logger */ return }
                if let newAnchor { anchorStore.save(newAnchor) }
                let slots = HealthDoseMatcher.slots(from: samples ?? [])     // matcher lands in #03
                Task { await onDoses(slots) }
            }
        let query = HKAnchoredObjectQuery(
            type: HKObjectType.medicationDoseEventType(),
            predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        liveQuery = query
        store.execute(query)
    }
}
```

## Constraints

**Scope fence:** The observation actor + anchor store + the `Sendable` slot boundary only. **No** concept-token matching / `Medication` resolution (child #03), **no** `RegimenSnapshot`/WC push (#04), **no** watch consumption (#05). Authorization already lands in #01 — call it, don't re-implement it. No HealthKit code in `Shared/`.

> **Open (confirm against Xcode 26 SDK):** exact spellings of `HKObjectType.medicationDoseEventType()` and `HKQuery.predicateForMedicationDoseEvent(withStatus:)`, and whether background delivery is available for this type (out of scope here — a follow-up only if latency proves unacceptable). Verify headers before coding.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps still build and run on the paired simulator. The readback service can be started and will deliver `.taken` dose-event deltas to its callback, with the anchor persisting across launches — but nothing is matched or synced yet, so the watch is unchanged. The next child consumes the emitted slots.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #70`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
