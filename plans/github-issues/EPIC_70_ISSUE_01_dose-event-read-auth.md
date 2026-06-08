## Role

You are a senior iOS / HealthKit engineer adding the **read** authorization scope for `HKMedicationDoseEvent` to PillBreakfast's existing HealthKit actor, plus the iPhone Settings affordance that requests it. This is the skeleton for Health dose readback enrichment: it stands up the authorization seam the later children build on, without yet observing or suppressing anything.

## Goal

Extend the HealthKit actor (`HealthKitImportService`, or a peer actor sharing the `HKHealthStore`) with `requestDoseEventReadAuthorization()` that requests per-medication **read** access for the `HKMedicationDoseEvent` sample type — a separate type from the Phase 6 medication grant. Surface it from a "Sync from Apple Health" section in the iPhone Settings tab with a clear usage string. The request **never** asks for write scope (none exists). After this PR, Settings can prompt for dose-event read access; nothing yet runs a query or suppresses a prompt.

## Context

- **Parent epic:** #70
- **Predecessors:** Phase 6 HealthKit import (`HealthKitImportService` actor, the `HealthKitImporting`-style protocol seam, `requestPerObjectReadAuthorization` for `userAnnotatedMedicationType()`, and the `HealthKitImportAuthorizationResult` enum already ship).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` §5.2 (authorization scope + the DTS "prompt finished ≠ granted" caveat), §7 (iPhone Settings additions), §9 (privacy — read-only, minimum data).
- **Files involved:**
  - `PillBreakfast/HealthKitImport/HealthKitImportService.swift` — add `requestDoseEventReadAuthorization()` (iOS-only target — never `Shared/`).
  - the `HealthKitImporting`-style protocol — extend so the readback auth path is exercised with a fake.
  - the iPhone Settings tab view (Tab 3, SPEC §6.3) — add a "Sync from Apple Health" section with the dose-event auth affordance. No logging UI.
  - the Info.plist `NSHealthShareUsageDescription` (or per-type usage string) — extend the usage copy to mention dose events.
  - `Shared/Models/Medication.swift` — `healthKitConceptID` (read-only reference; the join key, not touched here).
- **Prior decisions (locked):**
  - HealthKit Medications is **read-only and iOS-only**. All Health access stays in the `PillBreakfast` app target. The watch never queries Health.
  - Dose events are a **separate** sample type from the medication grant and need their own per-object read request.
  - A successful authorization request reports only that the *prompt finished*, never whether access was granted; read `authorizationStatus(for:)` stays `.notDetermined` by design. The only honest signal is "the query returned rows," so the feature must degrade to "no suppressions" when declined — never assume access.
  - `healthKitConceptID` is the match key, **never** a write channel. No write scope is requested anywhere.

## Output Format

A single PR containing:

- [ ] `requestDoseEventReadAuthorization() async throws -> HealthKitImportAuthorizationResult` on the HealthKit actor, calling `requestPerObjectReadAuthorization(for: HKObjectType.medicationDoseEventType(), predicate: nil)`, returning `.notAvailable` when `HKHealthStore.isHealthDataAvailable()` is false and `.denied` on `HKError.errorUserCanceled`.
- [ ] The `HealthKitImporting`-style protocol gains the new method so it is fakeable; the real `HKHealthStore`-touching actor is never instantiated in tests.
- [ ] iPhone Settings "Sync from Apple Health" section with a button/affordance that invokes the request, plus a placeholder diagnostic line ("last readback: —") that later children populate. No "take pills now" UI.
- [ ] Usage-string copy extended for dose-event read.
- [ ] Tests: the fake records that dose-event read auth was requested; `.notAvailable` is returned when health data is unavailable; the protocol method is exercised without instantiating the real store.

## Examples

```swift
// PillBreakfast/HealthKitImport/ (iOS-only target — never Shared/)
func requestDoseEventReadAuthorization() async throws -> HealthKitImportAuthorizationResult {
    guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
    do {
        try await store.requestPerObjectReadAuthorization(
            for: HKObjectType.medicationDoseEventType(),
            predicate: nil
        )
        return .authorized   // "prompt finished" — NOT "granted"; honest signal is rows returned later
    } catch let error as HKError where error.code == .errorUserCanceled {
        return .denied
    }
}
```

## Constraints

**Scope fence:** Authorization request + Settings affordance + usage string only. **No** `HKAnchoredObjectQuery` (that is core child #02), **no** matcher/resolution (#03), **no** `RegimenSnapshot` change or WC push (#04), **no** watch-side code (#05). **No** write scope of any kind. No HealthKit code in `Shared/`.

> **Open (confirm against Xcode 26 SDK before coding):** the exact spelling of `HKObjectType.medicationDoseEventType()`. The names here are inferred from the WWDC 2025 shape; verify against the shipping headers and adjust without changing the contract.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps still build and run on the paired simulator. The existing Phase 6 import flow is unchanged. The new Settings affordance can prompt for dose-event read access; with access granted nothing yet changes on the watch — the suppression machinery lands in later children.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #70`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `tracer-skeleton`, `concurrency`
