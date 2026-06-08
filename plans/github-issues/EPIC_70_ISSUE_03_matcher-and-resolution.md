## Role

You are a senior Swift engineer building the pure matching + resolution layer of Health dose readback: a side-effect-free `HealthDoseMatcher` that turns Health dose samples (and deletions) into `HealthTakenSlot`s / retractions, and a resolution step that maps each slot's concept token to a local `Medication.healthKitConceptID` and produces the resolved `HealthSuppressedSlotDTO`. This is the most heavily unit-tested child — it encodes the safety-critical "only concept-ID matches suppress" rule.

## Goal

Implement `HealthDoseMatcher` (no model context, no HK store) that maps `[HKSample]` → `[HealthTakenSlot]` and `[HKDeletedObject]` → retractions, archiving each dose's `HKHealthConceptIdentifier` to the **same** base64 token format `HealthKitImportService.draft(from:)` produces. Then implement the resolution layer that, given a `HealthTakenSlot` set and the live `Medication` set, drops unmatched tokens, resolves matches to `(medicationID, hour, minute, day)`, dedups within a day, and emits `HealthSuppressedSlotDTO`s. Concept-ID is the **only** join key; name matching is explicitly rejected.

## Context

- **Parent epic:** #70
- **Predecessor:** #70 child #02 (`EPIC_70_ISSUE_02_anchored-query-and-anchor-store.md` — the anchored query emits raw samples/deletions and the `HealthTakenSlot` boundary type).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` §5.4 (matching policy — concept-only, name rejected), §5.5 (resolve token → medicationID on the iPhone before sync), §6 (alternatives — fuzzy match rejected), §8 (dedup, scheduled-time tolerance, skipped/missed produce no slot), §10 (matcher + resolution tests).
- **Files involved:**
  - `PillBreakfast/HealthKitImport/HealthDoseMatcher.swift` (new) — pure `enum`/static funcs: `slots(from:)`, `retractedSlots(from:)`, `conceptToken(for:)`.
  - `PillBreakfast/HealthKitImport/HealthTakenSlot.swift` (new, or co-located) — `Codable, Sendable, Hashable` advisory record (concept token + dates). **Not** a `DoseEvent`.
  - the resolution layer (a pure function/type co-located in `HealthKitImport/`) producing `HealthSuppressedSlotDTO` from slots + `[Medication]`.
  - `PillBreakfast/HealthKitImport/HealthKitImportService.swift` — reference `draft(from:)` for the exact concept-token archive format to match against.
  - `PillBreakfast/HealthKitImport/HealthMedicationMapper.swift` — reference `isAlreadyImported(_:existingConceptIDs:)` for the set-membership matching pattern to mirror.
  - `Shared/Models/Medication.swift` — `healthKitConceptID` (the join key, read-only here).
- **Prior decisions (locked):**
  - **Only `healthKitConceptID` matches suppress.** Suppression works only for Health-imported meds (the sole path that populates the field). Manually-added meds carry no token and are never suppressed — correct. Fuzzy/name matching is **rejected** (risks suppressing the wrong drug, e.g. lithium vs. a look-alike).
  - `HealthTakenSlot` is an advisory `Sendable` value record — it **never** becomes a `DoseEvent`, never enters history or PRN totals. There is no `.health` `LogSource`.
  - `.skipped`/`.missed` samples produce **no** slot (the query already filters to `.taken`, but the matcher must not invent slots for non-taken statuses if any slip through).
  - Resolution happens **on the iPhone**: the watch receives resolved `(medicationID, hour, minute, day)` and never a concept token it can't use.
  - Dedup by `(medicationID, day, hour, minute)`. Scheduled-time alignment uses a tolerance window; if no slot matches within tolerance, do **not** suppress (tolerance value is an open question — make it a single named constant, easy to tune).

## Output Format

A single PR containing:

- [ ] `HealthTakenSlot` (`Codable, Sendable, Hashable`): `healthKitConceptID: String`, `takenAt: Date`, `scheduledFor: Date?`.
- [ ] `HealthDoseMatcher.slots(from: [HKSample]) -> [HealthTakenSlot]` and `retractedSlots(from: [HKDeletedObject]) -> [...]`, with `conceptToken(for:)` archiving the concept identifier to the `draft(from:)` token format.
- [ ] Resolution layer: `(slots: [HealthTakenSlot], medications: [Medication]) -> [HealthSuppressedSlotDTO]` (the DTO type may be introduced here as a plain value type and adopted into the snapshot by child #04, or stubbed minimally — keep it `Sendable`). Unmatched tokens dropped; resolved entries deduped within a day; a single named tolerance constant.
- [ ] Tests: concept-token round-trip equality against `HealthKitImportService.draft(from:)`'s format; a `.taken` sample → one slot; a `.skipped`/`.missed` shape → no slot; deletions → retractions; resolution drops unmatched concept tokens; resolution dedups duplicates within a day; a manually-added med (no token) is never matched.

## Examples

```swift
enum HealthDoseMatcher {
    /// Pure: no model context, no HK store. Returns advisory slots; the caller
    /// resolves them against the live Medication set.
    static func slots(from samples: [HKSample]) -> [HealthTakenSlot] {
        samples.compactMap { sample in
            guard let dose = sample as? HKMedicationDoseEvent else { return nil }
            guard let token = conceptToken(for: dose) else { return nil }
            return HealthTakenSlot(
                healthKitConceptID: token,
                takenAt: dose.startDate,
                scheduledFor: dose.scheduledDate   // the prescription slot the Health dose satisfied
            )
        }
    }
}

/// Sendable advisory record. NOT a DoseEvent — never enters history or PRN totals.
public struct HealthTakenSlot: Codable, Sendable, Hashable {
    public let healthKitConceptID: String
    public let takenAt: Date
    public let scheduledFor: Date?
}
```

## Constraints

**Scope fence:** The pure matcher + resolution only. **No** `HKAnchoredObjectQuery`/anchor work (child #02 — call its output), **no** `RegimenSnapshot` schema change or WC encode/push (#04), **no** watch consumption (#05). **No** fabrication of a `DoseEvent`. **No** name/fuzzy matching — concept-ID only. Keep all types `Sendable`; the matcher must be a pure function tested without a real `HKHealthStore`.

> **Open (confirm against Xcode 26 SDK):** the API surface for reading a dose event's `HKHealthConceptIdentifier`, `scheduledDate`, and `startDate`. Names are inferred from the WWDC 2025 shape; verify and keep the matcher behind a small protocol seam so fixtures can drive it without real samples.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps still build and run on the paired simulator. Health dose samples can now be matched to local meds and resolved into suppression DTOs (verified by unit tests), but the DTOs are not yet carried over WatchConnectivity, so the watch is still unchanged. Child #04 wires the resolved set into the snapshot.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #70`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`
