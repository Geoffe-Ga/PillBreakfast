## Role

You are a senior iOS engineer wading into HealthKit's per-medication authorization API. You know this is the API SPEC §11 calls "deliberately confusing" and that reading the docs critically is the senior skill being exercised.

## Goal

Implement `HealthKitImportService.requestPerMedicationReadAuthorization()` (iOS-only, `actor`-isolated) that requests the user's per-medication read scope. Handle the denial path with a meaningful empty state. No querying yet — that's EPIC_07_ISSUE_03.

## Context

- **Parent epic:** #7
- **Predecessor issue(s):** #EPIC_07_ISSUE_01_NUMBER.
- **SPEC section:** `plans/SPEC.md` §3.1, §10 Phase 6 ("iPhone HealthKit authorization flow (per-medication read)"), §11 Phase 6 skill callout.
- **Files involved:**
  - `iOSApp/HealthKitImport/HealthKitImportService.swift` — fill in the authorization request.
  - `iOSApp/HealthKitImport/HealthKitImportSheet.swift` — branch on the authorization result.
- **Prior decisions (locked):**
  - **Per-medication read scope**, not blanket read. The user picks which Health medications PillBreakfast sees.
  - **Denial is not an error.** It's a valid path that surfaces a "Re-enable in Settings > Privacy > Health" empty state.
  - HealthKit's per-object authorization API on iOS 26 may surface as `requestPerObjectReadAuthorization(for:predicate:)` or similar; confirm in Xcode 17 documentation before committing.
- **State of the world:** Stub sheet exists.

## Output Format

A single PR containing:

- [ ] `HealthKitImportService.requestPerMedicationReadAuthorization()` returning a typed result (`.authorized`, `.denied`, `.notAvailable` for sim devices without Health).
- [ ] `HealthKitImportSheet` branches on the result.
- [ ] Tests: the result enum has the three cases; the service is wrapped behind a protocol so the sheet can be tested with a fake.

## Examples

```swift
public enum HealthKitImportAuthorizationResult: Sendable {
    case authorized
    case denied
    case notAvailable
}

public protocol HealthKitImporting: Sendable {
    func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult
}

public actor HealthKitImportService: HealthKitImporting {
    private let store = HKHealthStore()

    public init() {}

    public func requestPerMedicationReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        // Concrete API surface confirmed in Xcode 17 docs:
        // try await store.requestPerObjectReadAuthorization(for: HKUserAnnotatedMedication.self, predicate: nil)
        // (Pseudocode; verify exact selector before merging.)
        return .authorized
    }
}
```

## Constraints

**Scope fence:** No querying / mapping — EPIC_07_ISSUE_03 and EPIC_07_ISSUE_04.

**Watch never sees this code.** Keep all files iOS-only.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** No regression; auth flow now runs but returns no medications.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #7` and `Closes #EPIC_07_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-6-healthkit`.
