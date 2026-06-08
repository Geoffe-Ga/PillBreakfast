## Role

You are a senior Swift 6 engineer finishing the pill-imagery feature: embed thumbnails in the PDF history export across the actor-detach boundary, garbage-collect orphaned assets, and ship the NLM attribution + privacy disclosure + nutrition-label delta.

## Goal

`PDFExporter` embeds each `.taken` event's pill thumbnail in the 30-day export, passing only `Sendable` `Data` across the detached `nonisolated` render boundary (never a live `UIImage` or model). An orphan-GC pass deletes `PillImageStore` files no live `imageAssetID` references. NLM RxImage attribution appears in Settings → About and the PDF footer band, and the privacy disclosure + nutrition-label delta for the name-leaves-device lookup ship.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_02 (`PillImageStore`), ISSUE_04 (images exist), ISSUE_06 (watch render done). This is the final polish child.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.6 (immutability open point), §5.7 (PDF embed), §8 (orphan GC), §9 (privacy & attribution).
- **Files involved:**
  - `PillBreakfast/HistoryTab/PDFExporter.swift` — `@MainActor enum`; `collectBlocks` (main actor) resolves the relevant `imageAssetID`, reads bytes via `PillImageStore`, packs them into the `Sendable` `PDFDayBlockSnapshot`/row snapshot as `Data?`; the detached `nonisolated render` draws via `UIImage(data:)`. Attribution rides `drawFooter` (alongside the existing seeded-ingredient disclaimer).
  - `Shared/Models/DoseEvent.swift` and `Shared/Sync/DoseEventBatchDTO.swift` — **only if** grooming adopts the §5.6 denormalization (`DoseEvent.loggedImageAssetID: UUID?` + additive `DoseEventDTO` field decoded with `decodeIfPresent`). **Default per the spec is live reference; do not add the field unless grooming says so.**
  - Settings → About surface; iOS privacy nutrition-label config / in-app disclosure.
- **Prior decisions (locked):**
  - Only `Data` crosses the detach boundary — never a live model or `UIImage` (preserves the existing isolation seam).
  - §5.6 default: live `Medication.imageAssetID` for the ritual; denormalized `DoseEvent.loggedImageAssetID` for history **only if adopted at grooming**.
  - Orphan GC compares `PillImageStore.allStoredIDs()` against live `imageAssetID`s (plus any denormalized refs) and deletes the rest; runs on iPhone after archive/edit and on watch after each regimen apply.
  - NLM attribution is required (attribution-only license). Decode failure → treated as a miss; never crashes the renderer.

## Output Format

A single PR containing:

- [ ] `PDFExporter` thumbnail embed: `Data?` packed into the day/row snapshot on main; drawn in the detached render via `UIImage(data:)`.
- [ ] Orphan-GC pass (iPhone after archive/edit; watch after regimen apply) deleting unreferenced `PillImageStore` files.
- [ ] NLM RxImage attribution in Settings → About and the PDF footer band.
- [ ] Privacy nutrition-label delta + in-app disclosure for the name-leaves-device lookup (opt-in affordance already exists from ISSUE_04).
- [ ] (Only if grooming adopts §5.6) `DoseEvent.loggedImageAssetID` + additive `DoseEventDTO` field with `decodeIfPresent`.
- [ ] Tests:
  - thumbnail embed renders; a `.taken` row with no image falls back to text.
  - the detached renderer receives only `Sendable` `Data` (no live model/`UIImage` crosses the boundary).
  - corrupt/oversized image → treated as a miss; render does not crash.
  - orphan GC deletes unreferenced files and keeps referenced ones.

## Examples

```swift
struct PDFDayRowSnapshot: Sendable {
  // …existing fields…
  let pillThumbnail: Data?   // resolved on main from PillImageStore; only Data crosses the detach
}
```

## Constraints

**Scope fence:** PDF embed, orphan GC, attribution + privacy only. Do not change the watch ritual, the add flow, or the WC transport. Do **not** add the denormalized `DoseEvent` field unless grooming has explicitly adopted §5.6.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The PDF still exports for a regimen with no images (text-only rows). With images, thumbnails appear and the PDF remains readable after email. Orphaned assets are reclaimed; attribution and disclosure are present.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `polish`, `concurrency`, `watch`
