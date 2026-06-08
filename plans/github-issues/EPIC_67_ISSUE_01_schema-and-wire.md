## Role

You are a senior Swift 6 / SwiftData engineer adding the schema and wire-format foundation for optional pill imagery. This is the tracer skeleton: the field and DTO flag land everywhere they belong, but nothing reads them yet — the app builds, runs, and syncs exactly as before.

## Goal

Add a single nullable `imageAssetID: UUID?` field to `Medication`, give the store a lightweight additive migration, and carry the flag across the WatchConnectivity wire so the watch knows an image is *expected*. The bytes are NOT sent in this issue — only the presence flag. v4 regimen payloads must still decode on this v5 build.

## Context

- **Parent epic:** #67
- **Predecessors:** none (first child of the epic). Gated on v1 complete + text-only tap-through dogfooded (SPEC §12.1).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.1 (schema delta & migration), §4 (current models/sync cited).
- **Files involved:**
  - `Shared/Models/Medication.swift` — add the nullable field; mirror the optional-link discipline of `healthKitConceptID` (presence is the only contract, no eager fetch).
  - `Shared/Persistence/PersistenceController.swift` — the `schema` array; additive lightweight migration like `SnoozeRecord` / `PillMeal` (confirm against the current store version; if a `VersionedSchema` already exists, add a new version with the field).
  - `Shared/Sync/RegimenSnapshot.swift` — bump `currentSchemaVersion` from 4 to 5; add `imageAssetID: UUID?` to `MedicationDTO`, decoded with `decodeIfPresent` per the existing `init(from:)` pattern.
- **Prior decisions (locked):**
  - Asset bytes never ride `updateApplicationContext` — the snapshot carries only the flag (the bytes use a separate file channel in ISSUE_05).
  - Additive, nullable, lightweight migration only — legacy rows default `imageAssetID = nil`.
  - `imageAssetID` is a filename-stem UUID for an on-disk asset, never a remote URL.

## Output Format

A single PR containing:

- [ ] `Medication.imageAssetID: UUID?` with a doc comment explaining it is a local-asset stem, never a URL, and mirrors `healthKitConceptID` discipline.
- [ ] Lightweight migration verified: a store with `imageAssetID`-less rows opens and defaults to `nil`.
- [ ] `RegimenSnapshot.currentSchemaVersion = 5`; `MedicationDTO.imageAssetID` encoded/decoded with `decodeIfPresent`.
- [ ] Tests:
  - A populated pre-migration store fixture opens; existing rows read `imageAssetID == nil`.
  - `MedicationDTO` round-trips `imageAssetID` through encode→decode.
  - A v4 (no `imageAssetID`) payload decodes on the v5 build with `imageAssetID == nil`.

## Examples

```swift
@Model
public final class Medication {
  // …existing fields…
  /// Filename-stem (UUID) of the locally-stored pill image asset, or nil for
  /// name-only meds. Never a remote URL — the asset is always on-disk in the
  /// App-Group container before this is set. Mirrors `healthKitConceptID`:
  /// presence is the only contract, no eager fetch.
  public var imageAssetID: UUID?
}
```

## Constraints

**Scope fence:** Schema + wire only. **No** `PillImageStore`, **no** `RxImageClient`, **no** UI, **no** file transfer, **no** read of the field anywhere. The field is dead-but-present.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator; a med added today saves and syncs exactly as before, with `imageAssetID == nil`. Nothing in the UI or watch changes.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `tracer-skeleton`
