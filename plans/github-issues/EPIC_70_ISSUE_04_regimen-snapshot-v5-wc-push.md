## Role

You are a senior Swift / WatchConnectivity engineer carrying the resolved Health suppression set from iPhone to watch. You add an additive `RegimenSnapshot` v5 field, encode/decode it, and wire the readback fire and regimen changes to recompute the suppression set and re-push it over the existing application-context channel.

## Goal

Add `healthSuppressedSlots: [HealthSuppressedSlotDTO]` to `RegimenSnapshot` as a **schema v5, additive** field (a v4 payload decodes with `[]`). Wire the `HealthDoseReadbackService` fire (and any regimen change) to recompute the resolved suppression set and re-push the regimen via `WatchConnectivityCoordinator` using `updateApplicationContext` ("latest wins," persists while the watch is offline). The hint is **day-scoped and ephemeral** — it suppresses today's slot only, recomputed and re-pushed on each readback or regimen change. iPhone → watch only.

## Context

- **Parent epic:** #70
- **Predecessor:** #70 child #03 (`EPIC_70_ISSUE_03_matcher-and-resolution.md` — the matcher + resolution produce `HealthSuppressedSlotDTO`s from slots + the live `Medication` set).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` §5.5 (crossing to the watch — regimen channel, resolve token → medicationID on the iPhone, day-scoped/ephemeral), §4.3 (iPhone → watch payload belongs on the regimen channel), §10 (`RegimenSnapshot` v5 additive-decode test mirroring the v3→v4 `pillMeals` default).
- **Files involved:**
  - `Shared/Sync/RegimenSnapshot.swift` — add the `healthSuppressedSlots` field + `HealthSuppressedSlotDTO`; bump `currentSchemaVersion` to v5 additively; default to `[]` when decoding older payloads.
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — the existing `updateApplicationContext` regimen push (`pushRegimen()`); recompute + re-push on readback fire and regimen change.
  - the iPhone wiring that owns `HealthDoseReadbackService` (from #02) and the resolution layer (from #03) — connect the `onDoses` callback to recompute the suppression set and trigger the re-push.
- **Prior decisions (locked):**
  - The suppression hint is iPhone → watch state, so it rides the **regimen / application-context channel**, not the dose-event file channel.
  - The schema is **additive**: `RegimenSnapshot` already versions additively (`currentSchemaVersion`); a v4 payload must decode with `healthSuppressedSlots == []` (mirror the existing v3→v4 `pillMeals` default test).
  - Resolve `healthKitConceptID → medicationID` **on the iPhone** before syncing. The watch's snapshot already carries `Medication.id` and `PendingQueueSelector` keys on `SlotKey(medicationID, hour, minute)`, so the DTO is `(medicationID, hour, minute, day)`. The watch never sees a concept token.
  - The hint is **day-scoped and ephemeral** — suppresses today's slot only; recomputed and re-pushed whenever the anchored query fires or the regimen changes; stale next-day suppressions are dropped on the watch side (that filter lands in child #05).
  - PillBreakfast still never fabricates a `DoseEvent`; the DTO is advisory only.

## Output Format

A single PR containing:

- [ ] `HealthSuppressedSlotDTO` (`Codable, Sendable, Hashable`): `medicationID: UUID`, `hour: Int`, `minute: Int`, `day: Date` (start-of-day).
- [ ] `RegimenSnapshot` gains `healthSuppressedSlots: [HealthSuppressedSlotDTO]` at schema v5, additively — encode includes it; decode of a v4 payload yields `[]`.
- [ ] `WatchConnectivityCoordinator` recomputes + re-pushes the regimen (with the current suppression set) on (a) a readback fire and (b) a regimen change, via `updateApplicationContext`.
- [ ] The iPhone wiring connects `HealthDoseReadbackService.startObserving(onDoses:)` → resolution (#03) → snapshot recompute → push.
- [ ] Tests: a v4 payload decodes with `healthSuppressedSlots == []`; a v5 round-trip preserves the slots; a readback fire triggers a re-push (via a fake coordinator/seam); the pushed DTOs carry resolved `medicationID`s, never concept tokens.

## Examples

```swift
// Shared/Sync/RegimenSnapshot.swift  (v5, additive — older payloads decode with [] default)
public let healthSuppressedSlots: [HealthSuppressedSlotDTO]

public struct HealthSuppressedSlotDTO: Codable, Sendable, Hashable {
    public let medicationID: UUID   // resolved on iPhone from healthKitConceptID
    public let hour: Int            // derived from scheduledFor in the watch-local calendar
    public let minute: Int
    public let day: Date            // start-of-day the suppression applies to
}
```

## Constraints

**Scope fence:** The additive snapshot field + encode/decode + the iPhone-side recompute/re-push wiring only. **No** watch-side consumption — `PendingQueueSelector` and `NotificationBootstrap` changes are child #05. **No** new HealthKit query/matcher work (children #02/#03 — consume their output). The watch never receives a concept token; only resolved UUIDs + times cross the wire.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps still build and run on the paired simulator. The watch now *receives* the resolved suppression set inside the regimen snapshot (decodable, day-scoped) — but does not yet act on it, so pending-dose cards and notifications are unchanged. Child #05 plugs the set into the queue and notification rebuild. Older snapshot payloads still decode (additive).

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #70`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
