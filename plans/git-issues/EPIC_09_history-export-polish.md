# EPIC 09 — Phase 8: History, PDF Export, and Polish

## Epic Summary

Geoff can hand his psychiatrist a PDF of the last 30 days. The iPhone History tab gains a calendar heatmap, per-day drill-down listing doses with timestamps + status + PRN running totals, filter-by-medication, and a "Export 30 days as PDF" action that opens the standard share sheet. The polish pass adds empty states, error handling, and a VoiceOver audit across every interactive element. Implements SPEC §10 Phase 8 (lines 491-501) and §6.2 in full.

## Scope

**In scope:**

- **iPhone History tab calendar heatmap** (last 30 days). Color discipline: monochromatic intensity (no rainbow); high-risk meds are not visually surfaced here since color is reserved for the active high-risk confirmation (EPIC 04, CLAUDE.md).
- **Per-day drill-down view:** chronological list of `DoseEvent`s for the day with timestamp, medication name, quantity, status icon (taken / skipped / snoozed), and PRN ingredient running totals for the day.
- **Filter by medication:** segmented control or sheet over the heatmap.
- **PDF export via `PDFKit`** for the most recent 30 days. The PDF shows a date-grouped log of every dose with time, medication, dosage, status, and per-day running ingredient totals for PRN meds. Pagination handled gracefully (no orphan rows). Embeds the seeded-ingredient disclaimer in a footer.
- **Standard share sheet integration** (`UIActivityViewController` or SwiftUI `ShareLink`) targeting Mail, Messages, Files.
- **Empty states everywhere** the user can land without data: empty history, no PRN logged today, all-clear root view. Use the EPIC 04 design system.
- **Error handling pass:** WatchConnectivity unreachable, HealthKit denied, SwiftData write failure. Each gets a user-readable message rather than a swallowed `try?`. (Follows max-quality-no-shortcuts.)
- **VoiceOver audit** on every interactive element across iPhone and watch: medication name, dose quantity, action button label, complication, widget. Accessibility labels and traits set explicitly.
- Unit tests for the PDF generator (deterministic fixture in, byte-stable output out via a structural snapshot rather than literal byte comparison).
- Email-round-trip test: generate a PDF from a known fixture, AirDrop it to macOS Preview / Mail and verify it opens cleanly. Manual; checked off in PR template.

**Out of scope:**

- Pill thumbnails in the PDF (SPEC §12 item 1, deferred to v1.1).
- App Store assets (EPIC 10).
- Crash reporting and mutation testing (EPIC 10).

## Critical Architecture (carry into every child issue)

- **The iPhone history surface still does not log doses.** No "quick log" button on a History day view. (CLAUDE.md.)
- **PDF rendering reads denormalized `DoseEvent.ingredientAmounts`**, not live `Medication.components`. This is what keeps historical accuracy correct if the user later edits a product's composition. SPEC §5.3.
- **PDF must work offline.** No network calls during rendering. RxImage thumbnails (future work) will be local assets.
- **Color discipline holds in the history view and the PDF.** Monochromatic heatmap. Status icons can use system glyphs but not custom colored chrome.

## Success Criteria

The epic is done when:

- [ ] The History tab shows a calendar heatmap of the last 30 days; tapping a day drills into a per-day list with running totals.
- [ ] "Export 30 days as PDF" produces a PDF that opens cleanly in Preview and Mail, with no orphaned rows, the seeded-ingredient disclaimer in the footer, and ingredient-level running totals for PRN entries.
- [ ] VoiceOver navigates every interactive element on both targets with meaningful labels.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #NNN — Skeleton: Add the History tab with a placeholder heatmap reading from SwiftData, wired but rendering stub data (EPIC_09_ISSUE_01).
- [ ] #NNN — Implement the 30-day calendar heatmap and per-day drill-down with status icons and PRN running totals (EPIC_09_ISSUE_02).
- [ ] #NNN — Filter-by-medication control on the heatmap and drill-down (EPIC_09_ISSUE_03).
- [ ] #NNN — `PDFKit` exporter that reads denormalized `DoseEvent.ingredientAmounts` and produces a paginated 30-day report with the seeded-ingredient disclaimer footer (EPIC_09_ISSUE_04).
- [ ] #NNN — Share sheet integration via SwiftUI `ShareLink` targeting Mail / Messages / Files (EPIC_09_ISSUE_05).
- [ ] #NNN — Empty states + error-handling pass (WatchConnectivity unreachable, HealthKit denied, SwiftData write failure) (EPIC_09_ISSUE_06).
- [ ] #NNN — VoiceOver audit across iPhone and watch interactive elements with explicit accessibility labels and traits (EPIC_09_ISSUE_07).

## Sequencing Notes

- **Depends on:** EPIC 03 (so `DoseEvent`s exist to render), EPIC 05 (so ingredient-level running totals are meaningful), EPIC 04 (design system).
- **Unblocks:** EPIC 10 (which assumes a complete v1 feature set).
- **Parallel-safe:** EPIC 06, EPIC 07, EPIC 08 are independent.

## SPEC Reference

`plans/SPEC.md` §2.4 (Doctor Export journey), §6.2 (History tab), §10 Phase 8 (lines 491-501), §11 (Phase 8 skill callout: `PDFKit`).

## Labels

`epic`, `spec-decomposition`, `phase-8-history-export`, `tracer-code`.
