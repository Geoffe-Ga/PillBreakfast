## Role

You are a senior iOS engineer producing the PDF Geoff hands his psychiatrist. You understand `PDFKit`, pagination, and that file I/O on iOS is its own genre of bug.

## Goal

Implement `PDFExporter.exportLast30Days(from: ModelContext) -> URL` producing a paginated PDF that lists every `DoseEvent` from the last 30 days, grouped by date, with time / medication / dosage / status / running per-day PRN ingredient totals. The file ends in the user's temp directory and is returned for the share sheet (EPIC_09_ISSUE_05).

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_03_NUMBER.
- **SPEC section:** `plans/SPEC.md` §2.4 (Doctor Export journey), §6.2 ("Export 30 days as PDF"), §10 Phase 8.
- **Files involved (new):**
  - `iOSApp/HistoryTab/PDFExporter.swift`.
  - `iOSApp/HistoryTab/PDFLayout.swift` — pagination + section helpers.
  - `PillBreakfastTests/HistoryTab/PDFExporterTests.swift`.
- **Prior decisions (locked):**
  - **Reads `DoseEvent.ingredientAmounts`**, not live `medication.components`. History must reflect the snapshot at log time.
  - **Pagination must not orphan rows.** Use a measurement pass to decide page breaks.
  - **Footer includes the seeded-ingredient disclaimer** (`IngredientLibrarySeeder.disclaimer`).
  - **No network.** Render entirely offline.
- **State of the world:** History tab fully functional; no export yet.

## Output Format

A single PR containing:

- [ ] `PDFExporter.exportLast30Days(...)` returning a temp `URL`.
- [ ] Pagination logic with no orphaned rows.
- [ ] Footer disclaimer.
- [ ] Tests: produces a non-empty PDF for fixture data; structural snapshot test (count of pages and headings against a known fixture); generates offline (assertion: no network adapter touched — informational, since iOS sandbox would block anyway).
- [ ] Manual checklist: open the generated PDF in Preview and Mail and verify it renders cleanly.

## Examples

```swift
public enum PDFExporter {
    public static func exportLast30Days(from context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "PillBreakfast",
            kCGPDFContextTitle: "PillBreakfast — last 30 days"
        ]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)  // US Letter
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PillBreakfast-\(Int(now.timeIntervalSince1970)).pdf")

        let summary = try HistoryQueries.last30DaysSummary(in: context, now: now, calendar: calendar)
        let layout = PDFLayout(pageRect: pageRect, disclaimer: IngredientLibrarySeeder.disclaimer)

        try renderer.writePDF(to: url) { ctx in
            for page in layout.pages(for: summary) {
                ctx.beginPage()
                page.render(in: ctx.cgContext)
            }
        }
        return url
    }
}
```

## Constraints

**Scope fence:** No share sheet — EPIC_09_ISSUE_05. No empty / error states beyond what already works on the History tab — EPIC_09_ISSUE_06.

**Read from denormalized snapshots only.** Reading `medication.components` to compute totals must be rejected.

**No network.** Rendering must work in airplane mode.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** PDF generation works in tests; share sheet next.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-8-history-export`.
