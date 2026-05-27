## Role

You are a senior SwiftUI engineer wiring the PRN surfaces. You understand the tracer-code rule: skeleton issues stub the data with hardcoded zeros so the next issues can replace each stub with real logic without breaking the demo.

## Goal

Add the watch PRN section list view and the iPhone PRN form, both reading from SwiftData via `@Query`, but with **stub ingredient totals** (always "0 mg today, no doses logged"). No quantity picker, no ceiling check, no row-rendering branching by combo vs. single-ingredient. This is the skeleton issue for EPIC 05.

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_04_ISSUE_05_NUMBER (full EPIC 04 must be merged).
- **SPEC section:** `plans/SPEC.md` §6.1 (PRN form area, currently a stub from EPIC 03), §7.3 (Watch PRN section).
- **Files involved (new):**
  - `WatchApp Watch App/PRNSection/PRNListView.swift` — list of PRN products with stub row text.
  - `iOSApp/RegimenTab/PRNFormSection.swift` — fills the stub area of `AddMedicationView` / `EditMedicationView`.
  - `Shared/Queries/PRNStubTotals.swift` — temporary helper returning zero totals.
- **Files updated:**
  - `WatchApp Watch App/RootView/RightNowView.swift` — add navigation to `PRNListView` ("Take as-needed" button per SPEC §2.3).
  - `iOSApp/RegimenTab/AddMedicationView.swift` / `EditMedicationView.swift` — surface the PRN form section when `kind == .prn`.
- **Prior decisions (locked):**
  - On the watch, the PRN section is reachable from the root via a "Take as-needed" affordance, not from the tap-through queue. SPEC §2.3.
  - PRN configuration on iPhone allows the user to enter combo components (multiple `MedicationComponent`s); this skeleton issue ships the form fields but the form's save semantics are EPIC_05_ISSUE_06.
- **State of the world:** EPIC 04 ends with a complete maintenance flow. PRN is half-stubbed in `EditMedicationView` and absent from the watch.

## Output Format

A single PR containing:

- [ ] `PRNListView` showing all non-archived PRN medications with stub row text: `"<name> · 0 mg today · no doses logged"`.
- [ ] `PRNFormSection` on iPhone with `prnAvailableQuantities` editor and a "Components" sub-section listing the current components and an "Add ingredient" button (functional in EPIC_05_ISSUE_06).
- [ ] Navigation from `RightNowView` to `PRNListView` via a button labeled "Take as-needed."
- [ ] Smoke tests for both views with a fixture regimen containing one PRN product.

## Examples

`PRNStubTotals`:

```swift
public struct PRNRowSummary: Sendable, Hashable {
    public let medicationID: UUID
    public let displayName: String
    public let summaryText: String  // "0 mg today · no doses logged"
}

@MainActor
public enum PRNStubTotals {
    public static func summaries(in context: ModelContext) throws -> [PRNRowSummary] {
        let descriptor = FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived && $0.kind == .prn })
        let meds = try context.fetch(descriptor)
        return meds.map { PRNRowSummary(medicationID: $0.id, displayName: $0.displayName, summaryText: "0 mg today · no doses logged") }
    }
}
```

## Constraints

**Scope fence:** No real running totals — EPIC_05_ISSUE_02. No `violationsIfTaken` — EPIC_05_ISSUE_03. No quantity picker or row variant rendering — EPIC_05_ISSUE_04. No interstitial — EPIC_05_ISSUE_05.

**iPhone never gets logging UI.** The PRN form is for *configuring* a PRN product, not for logging a PRN dose.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both targets build; the watch root view has a new "Take as-needed" entry that opens a stub list.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-4-prn-safety`.
