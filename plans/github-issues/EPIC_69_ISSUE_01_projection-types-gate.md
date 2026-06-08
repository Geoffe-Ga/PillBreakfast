## Role

You are a senior Swift 6 engineer laying the caregiver-mode foundation: confirm the CloudKit prerequisite, then define the minimal read-only projection value types that a caregiver will ever see — with data minimization enforced at the type level. This is the tracer skeleton: pure value types and tests, no CloudKit, no sharing.

## Goal

Verify #68 (CloudKit private DB) is shipped and stable (document the dependency), then define `CaregiverRegimenProjection` and `CaregiverAdherenceProjection` as `Sendable` value types derived from the existing DTOs. Notes and free-text must not exist as fields on these types. Unit tests assert the minimization at the schema level.

## Context

- **Parent epic:** #69
- **Predecessors:** **#68 (epic) must be shipped + stable** — `CKShare` operates on records in a CloudKit zone, which only exists once the store is CloudKit-backed. This child is the prerequisite gate plus the projection types.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §4 (current state / DTOs as projection source), §5.1 (recommended architecture), §5.2 (why a projection), §5.5 (concurrency), §10 (testing — notes never appear).
- **Files involved:**
  - `Shared/Sync/RegimenSnapshot.swift` (`MedicationDTO` / `ScheduledDoseDTO`) and `Shared/Sync/DoseEventBatchDTO.swift` (`DoseEventDTO`) — the `Codable, Sendable` value types the projections are built **from** (not the live model graph).
  - `Shared/Models/LoggedIngredientAmount.swift` — `nonisolated struct … Codable, Sendable`; the pattern any new projection value type follows.
  - `Shared/Models/Enums.swift` (`LogSource`) — deliberately **not** extended with a `.caregiver` case.
  - New projection value types (e.g. `Shared/Caregiver/CaregiverProjections.swift`).
- **Prior decisions (locked):**
  - Share a **purpose-built minimal projection**, never the raw model/record graph (data minimization at the schema level makes consent toggles enforceable, not cosmetic).
  - `CaregiverRegimenProjection`: med display names + schedules only. `CaregiverAdherenceProjection`: per-day taken/skipped/pending per scheduled dose. **Notes / free text are never a field.**
  - `LogSource` is not extended; caregivers don't log.
  - Concurrency reuses MainActor-collect → Sendable-value-type; no `@unchecked Sendable`.

## Output Format

A single PR containing:

- [ ] A documented prerequisite note in the PR: #68 must be shipped + stable; if descoped, this epic is blocked (PDF export is the only non-live fallback).
- [ ] `CaregiverRegimenProjection` (`Sendable`): med display names + schedules; built from `MedicationDTO`/`ScheduledDoseDTO`.
- [ ] `CaregiverAdherenceProjection` (`Sendable`): per-day taken/skipped/pending per scheduled dose; built from `DoseEventDTO`.
- [ ] Projection builders (MainActor-collect → Sendable) from the existing DTOs.
- [ ] Tests:
  - the projection types have **no** notes/free-text field (compile-time + reflective assertion).
  - building a regimen projection from a DTO with notes drops the notes entirely.
  - adherence projection emits exactly per-day status, no raw minute-level fields unless configured.

## Examples

```swift
public struct CaregiverRegimenProjection: Sendable, Codable, Hashable {
  public let medicationDisplayName: String
  public let schedule: [ScheduledDoseSummary]   // times only; no notes, no raw ingredient library
  // there is deliberately NO `notes` field — minimization at the type level
}
```

## Constraints

**Scope fence:** Prerequisite gate + projection value types + builders only. **No** CloudKit zone, **no** `CKShare`, **no** consent UI, **no** viewer. Notes must not be representable.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; the projection types exist and are unit-tested but nothing produces or shares them at runtime yet. The watch is untouched.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `tracer-skeleton`
