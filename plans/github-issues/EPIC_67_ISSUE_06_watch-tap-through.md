## Role

You are a senior watchOS / SwiftUI engineer making the watch tap-through ritual image-first when a pill image is cached, while preserving the offline, no-network, no-spinner guarantee that defines the product.

## Goal

In `MarkTakenView`, when the medication's `imageAssetID` resolves to bytes in `PillImageStore`, render the thumbnail image-first in the hero card (above/inline with the name, which stays for accessibility). When there is no asset, the view renders byte-for-byte as it does today. The image loads once from disk when the queue screen appears — never a network call, never a spinner.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_02 (`PillImageStore`) and ISSUE_05 (bytes arrive on the watch).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §7 (watch UX), §8 (watch missing asset), §10 (testing), §13 (no-network device test).
- **Files involved:**
  - `PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift` — add the image-first branch in the existing hero `VStack`; load from `PillImageStore` when the screen appears.
- **Prior decisions (locked):**
  - **Offline-ritual rule (hard):** the tap-through must render identically whether or not the network exists. Asset present → image; absent → text. Never a spinner, never a fetch. The watch never hits the network for images.
  - Name stays visible for accessibility/VoiceOver even when the image is shown.
  - Color discipline: the photographed pill carries its own colors; no chrome/accent color introduced; amber stays reserved for high-risk press-and-hold.
  - Watch missing asset (offline during transfer) → fall back to text; the iPhone re-queues on next regimen push (handled in ISSUE_05).

## Output Format

A single PR containing:

- [ ] `MarkTakenView` image-first hero branch: load `imageAssetID` bytes from `PillImageStore` once on appear; show `Image` above/inline with the name on the existing glass card.
- [ ] Text-only fallback path unchanged when `imageAssetID == nil` or the asset is missing.
- [ ] Tests:
  - snapshot: image-present render vs. name-only render.
  - missing-asset (id set, no bytes) falls back to text — no spinner.
  - offline path never triggers a network call (no network dependency in the view).
  - VoiceOver: the image-first screen still announces medication name + dose.

## Examples

```swift
// in MarkTakenView hero VStack:
if let id = medication.imageAssetID, let data = loadedImageData {
  Image(uiImage: UIImage(data: data) ?? .init())   // resolved on appear from PillImageStore; no network
}
Text(medication.displayName)   // always present, VoiceOver anchor
```

## Constraints

**Scope fence:** Watch tap-through rendering only. **No** network code on the watch under any path. **No** PDF (ISSUE_07), **no** iPhone changes, **no** WC changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** With an image cached, the watch tap-through shows it. With no image, the screen is identical to today. In airplane mode, both behave identically to online — no spinner, no fetch.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `watch`
