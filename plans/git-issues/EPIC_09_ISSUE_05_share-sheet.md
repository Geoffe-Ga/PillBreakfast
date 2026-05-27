## Role

You are a senior SwiftUI engineer adding the share-sheet entry point.

## Goal

Add an "Export 30 days as PDF" button on the History tab that calls `PDFExporter.exportLast30Days(...)` and presents a SwiftUI `ShareLink` targeting Mail / Messages / Files.

## Context

- **Parent epic:** #9
- **Predecessor issue(s):** #EPIC_09_ISSUE_04_NUMBER.
- **SPEC section:** `plans/SPEC.md` §2.4, §6.2.
- **Files updated:** `iOSApp/HistoryTab/HistoryTabView.swift` — add the share button.
- **State of the world:** PDF generator works; no UI entry.

## Output Format

A single PR containing:

- [ ] Share button on History tab.
- [ ] `ShareLink(item: url, preview: SharePreview("PillBreakfast — last 30 days"))`.
- [ ] Manual checklist: tap Export, share to Mail (simulator-friendly), confirm the PDF arrives.

## Constraints

**Scope fence:** No empty/error states — EPIC_09_ISSUE_06. No accessibility audit — EPIC_09_ISSUE_07.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End-to-end export works.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #9` and `Closes #EPIC_09_ISSUE_05_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-8-history-export`.
