## Role

You are a senior watchOS engineer turning the EPIC_05_ISSUE_01 stub PRN list into the real thing. You understand SwiftUI navigation on the watch and the row-rendering rules from SPEC §7.3.

## Goal

Replace the stub PRN list rows with the three real variants from SPEC §7.3 (single-ingredient prescription, single-ingredient OTC, combo product). Add the quantity picker screen wired to `prnAvailableQuantities`. Drive ingredient totals from `IngredientQueries`. Logging a PRN dose writes a `DoseEvent` via `DoseEventWriter` with a complete `ingredientAmounts` snapshot.

## Context

- **Parent epic:** #5
- **Predecessor issue(s):** #EPIC_05_ISSUE_03_NUMBER (so the safety check exists, even though this issue does not yet surface the interstitial — EPIC_05_ISSUE_05 wires it in).
- **SPEC section:** `plans/SPEC.md` §2.3 (PRN journey), §7.3 (Watch PRN section).
- **Files involved:**
  - `WatchApp Watch App/PRNSection/PRNListView.swift` — replace stub rows with three real variants.
  - `WatchApp Watch App/PRNSection/PRNRowView.swift` (new) — handles the variant rendering.
  - `WatchApp Watch App/PRNSection/PRNQuantityPickerView.swift` (new) — quantity picker driven by `prnAvailableQuantities`.
  - `Shared/Queries/PRNRowSummaryBuilder.swift` (new) — pure helper that turns a `Medication` + queries into a `PRNRowSummary` with the right summary text.
- **Prior decisions (locked):**
  - **Row text variants:**
    - Single-ingredient prescription (e.g. Gabapentin): `"Gabapentin · 600 mg today · last 11:42 AM"`.
    - Single-ingredient OTC (e.g. Tylenol): `"Tylenol · 1500 mg acetaminophen today · last 11:42 AM"`.
    - Combo product: `"Excedrin · last 11:42 AM · acetaminophen 38% of daily limit"` (highest-utilization ingredient).
  - **Last-dose timestamp reflects the *product*, not the ingredient** (SPEC §7.3). Safety checks aggregate by ingredient; row labels show product-last-time.
  - **High-risk press-and-hold rules from EPIC 04 apply** if a PRN med happens to be high-risk. Hold on confirm.
- **State of the world:** EPIC_05_ISSUE_03 merged. Stub list + stub form present.

## Output Format

A single PR containing:

- [ ] `PRNRowSummaryBuilder.summary(for: Medication, at: Date, in: ModelContext)` returning a `PRNRowSummary` with the right variant text.
- [ ] `PRNRowView` consuming the summary.
- [ ] `PRNQuantityPickerView` letting the user pick from `prnAvailableQuantities` (or a freeform integer if empty — but warn).
- [ ] Confirm writes a `DoseEvent` via `DoseEventWriter` (already snap-shotting `ingredientAmounts`). The reverse-sync from EPIC_03_ISSUE_05 carries it to iPhone.
- [ ] Tests for `PRNRowSummaryBuilder` covering each of the three variants.

## Examples

`PRNRowSummary`:

```swift
public struct PRNRowSummary: Sendable, Hashable {
    public let medicationID: UUID
    public let displayName: String
    public let firstLine: String           // medication name, possibly with primary ingredient
    public let secondLine: String          // today total / last-dose info
    public let highlightedIngredientID: UUID?
}
```

Variant builder logic (abridged):

```swift
public enum PRNRowSummaryBuilder {
    public static func summary(
        for medication: Medication,
        at now: Date,
        in context: ModelContext
    ) throws -> PRNRowSummary {
        let lastDose = try IngredientQueries.lastProductDoseTime(medication: medication, in: context, before: now)
        let lastDoseText = lastDose.map { "last \($0.shortTime)" } ?? "no doses yet"
        let single = medication.components.count == 1

        if single, let component = medication.components.first, let ingredient = component.ingredient {
            let total = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now)
            let totalLabel = ingredient.name == medication.displayName ? "\(Int(total)) mg today" : "\(Int(total)) mg \(ingredient.name.lowercased()) today"
            return PRNRowSummary(
                medicationID: medication.id, displayName: medication.displayName,
                firstLine: medication.displayName,
                secondLine: "\(totalLabel) · \(lastDoseText)",
                highlightedIngredientID: ingredient.id
            )
        }

        // Combo path: pick the highest-utilization ingredient.
        var best: (Ingredient, percent: Double)?
        for component in medication.components {
            guard let ingredient = component.ingredient, let ceiling = ingredient.dailyCeilingMg else { continue }
            let today = try IngredientQueries.totalToday(ingredient: ingredient, in: context, at: now)
            let percent = today / ceiling
            if percent > (best?.percent ?? -1) { best = (ingredient, percent) }
        }
        let bestSuffix = best.map { " · \($0.0.name.lowercased()) \(Int($0.percent * 100))% of daily limit" } ?? ""
        return PRNRowSummary(
            medicationID: medication.id, displayName: medication.displayName,
            firstLine: medication.displayName, secondLine: "\(lastDoseText)\(bestSuffix)",
            highlightedIngredientID: best?.0.id
        )
    }
}
```

## Constraints

**Scope fence:** No soft warning interstitial — EPIC_05_ISSUE_05. No Ingredients screen — EPIC_05_ISSUE_06. Confirming a PRN dose in this issue writes without consulting `SafetyEvaluator`; the interstitial layer is added next.

**Last-dose label is per product, safety is per ingredient.** Mixing these up is the bug SPEC §7.3 explicitly warns against.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** PRN logging works end-to-end on the watch; the safety warning is the next issue's responsibility.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #5` and `Closes #EPIC_05_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-4-prn-safety`.
