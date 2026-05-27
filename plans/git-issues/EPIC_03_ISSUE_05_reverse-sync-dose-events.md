## Role

You are a senior Apple-platforms engineer wiring the reverse-sync channel: watch -> iPhone. You understand `WCSession.transferFile`, `WCSession.transferUserInfo`, and the trade-offs between them for batched vs. single-event payloads.

## Goal

When the watch writes a `DoseEvent`, transmit it to the iPhone so the iPhone's SwiftData store gains an idempotent merge of the event. The iPhone can then surface those events in a future History tab (EPIC 09). Use `WCSession.transferFile` to send a small JSON file containing one or more `DoseEvent`s; the iPhone-side handler decodes and upserts keyed on `DoseEvent.id`.

## Context

- **Parent epic:** #3
- **Predecessor issue(s):** #EPIC_03_ISSUE_03_NUMBER (watch writes `DoseEvent`s).
- **SPEC section:** `plans/SPEC.md` §4 (Sync row; "Direct phone <-> watch for initial regimen seed and history"), §10 Phase 2 ("Reverse sync: `DoseEvent`s from watch -> iPhone history").
- **Files involved (new):**
  - `Shared/Sync/DoseEventBatchDTO.swift` — `Codable, Sendable` DTO mirroring `DoseEvent` (plus `LoggedIngredientAmount`).
  - `Shared/Sync/DoseEventBatchTransfer.swift` — encode-write-transferFile sequence on the watch; decode-merge sequence on the iPhone.
- **Files updated:**
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — add `session(_:didReceive:)` (file) on iPhone; trigger a transfer after every `DoseEventWriter.writeDoseEvent` on the watch.
- **Prior decisions (locked):**
  - **`transferFile`, not `sendMessage`.** Files are queued and delivered when the iPhone becomes reachable; this survives the iPhone being off-wrist or asleep. `sendMessage` requires reachability.
  - **Upsert by `DoseEvent.id`** on the iPhone side. Receiving a duplicate event is a no-op. (Geoff could log on the watch, the watch transfers, the iPhone gets the event; later the user could re-import from a backup, and we don't want to duplicate.)
  - The watch keeps its own copy. We do not delete from the watch after transfer — both stores are authoritative on their respective devices, and the watch's PRN running-total queries need today's `DoseEvent`s to be local for speed.
  - Batching: transfer immediately on every write for now (we can debounce in a polish pass). The file is tiny.
- **State of the world:** EPIC_03_ISSUE_04 has landed. The watch can log doses; the iPhone has no awareness of them.

## Output Format

A single PR containing:

- [ ] `DoseEventBatchDTO` mirroring the schema fields needed to reconstruct a `DoseEvent` on iPhone, including a denormalized `medicationID: UUID` (because the medication already exists on iPhone via the regimen snapshot — we link by ID, not by re-sending the `Medication`).
- [ ] `DoseEventBatchTransfer.transfer(_ events: [DoseEvent]) async throws` on the watch — encodes to a temp JSON file and calls `WCSession.default.transferFile(_:metadata:)` with a metadata dictionary `["kind": "doseEventBatch"]`.
- [ ] `WatchConnectivityCoordinator.session(_:didReceive:)` (the file variant) on iPhone — checks metadata kind, decodes, upserts by `id`, fetches the `Medication` by `medicationID` to attach the relationship.
- [ ] After every successful `DoseEventWriter.writeDoseEvent` call on the watch, fire the transfer.
- [ ] Unit tests on the DTO Codable round-trip and on the upsert logic (idempotent merge with duplicate IDs).

## Examples

`DoseEventBatchDTO`:

```swift
public struct DoseEventDTO: Codable, Sendable, Hashable {
    public let id: UUID
    public let medicationID: UUID
    public let scheduledFor: Date?
    public let takenAt: Date
    public let quantity: Int
    public let status: DoseStatus
    public let loggedOn: LogSource
    public let notes: String?
    public let ingredientAmounts: [LoggedIngredientAmount]
}

public struct DoseEventBatch: Codable, Sendable, Hashable {
    public var events: [DoseEventDTO]
}
```

Idempotent merge on iPhone:

```swift
@MainActor
public enum DoseEventBatchMerger {
    public static func merge(_ batch: DoseEventBatch, into context: ModelContext) throws -> (inserted: Int, updated: Int) {
        var inserted = 0, updated = 0
        for dto in batch.events {
            let existing = try context.fetch(FetchDescriptor<DoseEvent>(
                predicate: #Predicate { $0.id == dto.id }
            )).first
            if let existing {
                // Updating a snapshot from a watch is unusual — only allow notes update.
                existing.notes = dto.notes
                updated += 1
            } else {
                guard let med = try context.fetch(FetchDescriptor<Medication>(
                    predicate: #Predicate { $0.id == dto.medicationID }
                )).first else { continue }
                let event = DoseEvent(
                    id: dto.id, medication: med, scheduledFor: dto.scheduledFor,
                    takenAt: dto.takenAt, quantity: dto.quantity, status: dto.status,
                    loggedOn: dto.loggedOn, ingredientAmounts: dto.ingredientAmounts
                )
                context.insert(event)
                inserted += 1
            }
        }
        try context.save()
        return (inserted, updated)
    }
}
```

Manual checklist:

1. iPhone: add "Vitamin D 2000mg" at 8:00 AM daily.
2. Watch: log the dose at 8:00 AM.
3. Within 30 seconds (i.e., next reachability window on the paired simulator), the iPhone's local `DoseEvent` count for today increments by 1.
4. Log the same dose again on the watch (e.g., reset simulator and re-tap). The iPhone has 2 `DoseEvent`s, not 3 — duplicates by `id` are idempotent.

## Constraints

**Scope fence:** Do not add a History UI on iPhone — EPIC 09. Do not delete `DoseEvent`s from the watch after transfer. Do not write a debounce/batching layer; transfer per write for now.

**Idempotency by `id` is required.** A re-transferred event must not duplicate. The merge test must cover this.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets build; iPhone Regimen tab + watch tap-through queue work; iPhone now silently gains `DoseEvent`s that no UI surfaces yet. EPIC 09 will surface them.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; the manual checklist completes.
- [ ] PR opened with `Refs #3` and `Closes #EPIC_03_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-2-maintenance`.
