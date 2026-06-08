## Role

You are a senior SwiftUI / Swift 6 engineer wiring the iPhone add-medication flow so a user can optionally attach a pill image — chosen from RxImage candidates, captured with the camera, or skipped entirely.

## Goal

In `MedicationFormView`, after a name is entered, surface an "Add pill image" affordance: a horizontally-scrolling Liquid-Glass strip of 0–5 RxImage candidates (with color/shape/imprint captions), a "Take a photo" path, and "Skip — name only." Selecting a candidate fetches + downscales via `RxImageClient`, writes bytes via `PillImageStore`, and sets the draft `imageAssetID`. The flow is fully skippable; a name-only med saves exactly as today.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_02 (`PillImageStore`) and ISSUE_03 (`RxImageClient`). The field from ISSUE_01 now gets its first writer.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.5 (concurrency), §7 (UX), §8 (edge cases), §9 (privacy — name leaves device).
- **Files involved:**
  - `PillBreakfast/RegimenTab/MedicationFormView.swift` — the candidate strip + "Take a photo" + "Skip" rows attach here (`Name`/`Form`/`Ingredient`/`Schedule` sections).
  - `PillBreakfast/RegimenTab/MedicationFormState.swift` — `@MainActor @Observable`; holds the new `imageAssetID` draft field; `await`s the client and store; persists via `apply(to:in:)` alongside the existing deferred-field `TODO`.
  - iOS target `Info.plist` — add `NSCameraUsageDescription`.
- **Prior decisions (locked):**
  - Fully skippable — no regression to the zero-friction name-only add.
  - Networking/decode off-main (in the client); only `Data`→`UIImage` preview and the `imageAssetID` write happen on the main actor.
  - Color discipline: the photographed pill carries its own colors, but **no** chrome/accent color is introduced; amber stays reserved for high-risk press-and-hold.
  - RxImage miss or network-down → "Couldn't load suggestions," photo/skip still available, med saves fine. Camera-permission-denied → fall back to name-only.

## Output Format

A single PR containing:

- [ ] `MedicationFormState` gains a draft `imageAssetID` and an injected `RxImageClient`; `apply(to:in:)` persists the field.
- [ ] `MedicationFormView` "Add pill image" section: candidate strip, "Take a photo," "Skip — name only," on the existing `LiquidGlassTheme.Materials.surface` card.
- [ ] Selecting a candidate: fetch via client → write via `PillImageStore` → set `imageAssetID`.
- [ ] `NSCameraUsageDescription` in the iOS target Info.plist.
- [ ] Tests (client injected as a fixture stub; no live network):
  - choosing a candidate sets `imageAssetID` and the asset exists in the store.
  - "Skip" leaves `imageAssetID == nil`; med saves normally.
  - empty candidates → photo/skip path still works; save succeeds.
  - client error → "Couldn't load suggestions" state; save still succeeds.

## Examples

```swift
@MainActor @Observable
final class MedicationFormState {
  var imageAssetID: UUID?
  private let rxImageClient: RxImageClient
  // on candidate pick:
  // let data = try await rxImageClient.thumbnailData(for: candidate)
  // let id = UUID(); try await PillImageStore.shared.write(data, for: id)
  // imageAssetID = id
}
```

## Constraints

**Scope fence:** iPhone add/edit flow only. **No** WC transfer (ISSUE_05), **no** watch UI (ISSUE_06), **no** PDF (ISSUE_07). Do not redesign the existing form sections.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** A user adds a name-only med and the flow is unchanged from today. A user who picks a candidate or photo saves a med whose `imageAssetID` resolves to bytes on disk. Nothing is transferred to the watch yet (next issue) and nothing reads the image on the watch yet.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
