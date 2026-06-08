## Role

You are a senior SwiftData / Swift 6 engineer making the data model CloudKit-compatible without yet turning CloudKit on. This is the tracer skeleton: the schema changes and a versioned migration land and migrate a populated store cleanly, while the app stays local-only and behaves exactly as today.

## Goal

Drop `@Attribute(.unique)` from every model `id`, confirm all relationships are optional / collections default-empty, and introduce an explicit `VersionedSchema` + `SchemaMigrationPlan` that migrates the current populated local store to the CloudKit-compatible schema with no data or relationship loss. No `cloudKitDatabase:` argument is added in this issue.

## Context

- **Parent epic:** #68
- **Predecessors:** none (first child). Gated on v1 complete + the data model stabilized through dogfooding.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` §4 (conflicting schema features), §5.2 (schema changes CloudKit forces), §10 (migration testing), §11 (`.unique` blast radius).
- **Files involved:**
  - All `Shared/Models/*.swift` — remove `@Attribute(.unique)` from `id` on `Ingredient`, `MedicationComponent`, `Medication`, `ScheduledDose`, `DoseEvent`, `PillMeal`; verify no relationship is non-optional-singular; `Medication`'s child arrays and `PillMeal.scheduledDoses` default to `[]`.
  - `Shared/Persistence/PersistenceController.swift` — `schema` array `[Ingredient, MedicationComponent, Medication, ScheduledDose, DoseEvent, SnoozeRecord, PillMeal]`; add the `VersionedSchema` + `SchemaMigrationPlan` (the `.unique`→non-unique change is metadata-only; stored data is unaffected).
  - Audit the merge paths that the uniqueness invariant was implicitly leaning on: `Shared/Sync/RegimenSnapshot.swift` (`apply(to:)`), `Shared/Sync/DoseEventBatchDTO.swift` / the dose merger, `PillBreakfast/RegimenTab/MedicationFormState.swift` (`apply`). All already fetch-by-id and upsert; confirm every `FetchDescriptor` assuming at-most-one row uses `.first`.
- **Prior decisions (locked):**
  - CloudKit forbids `.unique`; the uniqueness invariant is replaced by application-level upsert-by-id, which the codebase already does everywhere it matters — removing `.unique` is therefore lower-risk here than usual.
  - Keep `deleteRule: .cascade` for local behavior; CloudKit replays cascade locally per device. Archive-never-delete remains the safety net.
  - Stage the transition as a single `VersionedSchema` migration validated against a populated local fixture.

## Output Format

A single PR containing:

- [ ] `@Attribute(.unique)` removed from every `id`; relationship optionality / default-empty collections confirmed.
- [ ] `VersionedSchema` + `SchemaMigrationPlan` for the `.unique`-removal transition.
- [ ] Audit note in the PR: every fetch/merge that could now see duplicate ids is upsert-by-id and uses `.first`.
- [ ] Tests:
  - a populated pre-migration store fixture (with `.unique` ids + cascade graphs) migrates cleanly; row counts and relationships preserved.
  - upsert-by-id paths (`RegimenSnapshot.apply`, dose merge, `MedicationFormState.apply`) still produce exactly one row per id.
  - cascade delete still removes children locally post-migration.

## Examples

```swift
@Model
public final class Medication {
  // before: @Attribute(.unique) public var id: UUID
  public var id: UUID   // uniqueness now enforced by upsert-by-id in every merge path
}
```

## Constraints

**Scope fence:** Schema discipline + migration only. **No** `cloudKitDatabase:`, **no** entitlements, **no** Settings UI, **no** behavioral change. The app stays local-only and identical to today.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator; an existing populated store opens after migration with all rows and relationships intact; regimen push and dose merge behave exactly as before. No cloud anywhere.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #68`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `tracer-skeleton`
