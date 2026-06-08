## Role

You are a senior Swift 6 engineer extending the WatchConnectivity layer to deliver pill image bytes from the iPhone to the watch, reusing the existing `metadata["kind"]`-keyed file-transfer pattern. The iPhone is authoritative; the watch is a read-only cache.

## Goal

When a med's `imageAssetID` is first set (or changed), the iPhone calls `WCSession.transferFile` for the asset with `metadata[kind] == "pillImage"`. The watch's `session(_:didReceive file:)` branches on that kind, reads the bytes immediately (the URL is valid only during the call), and writes them via `PillImageStore`. On each regimen push, the iPhone idempotently re-queues any referenced asset the watch hasn't confirmed, so an offline watch eventually converges. No watch UI changes yet.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_01 (DTO flag), ISSUE_02 (`PillImageStore`), ISSUE_04 (iPhone sets `imageAssetID`).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.4 (WC image transfer flow), §5.5 (concurrency), §8 (watch-missing-asset edge).
- **Files involved:**
  - `Shared/Sync/DoseEventBatchTransfer.swift` — the canonical `transferFile` producer/consumer with `metadataKindKey: metadataKind`; mirror it for a second `kind`.
  - `Shared/Sync/WatchConnectivityCoordinator.swift` — `@MainActor @Observable` `WCSessionDelegate`; `session(_:didReceive file:)` already demultiplexes file transfers by `metadata["kind"]` — add the `"pillImage"` branch here. Add the producer-side transfer trigger on `imageAssetID` set/change and the re-queue on regimen push.
  - New `PillImageTransfer` metadata constants (e.g. `Shared/Sync/PillImageTransfer.swift`).
- **Prior decisions (locked):**
  - Reuse the same metadata key (`"kind"`) as dose batches; the dose-batch path must not regress.
  - `transferFile` queues until the watch is reachable (survives an asleep watch) — same guarantee the dose channel relies on.
  - iPhone-authoritative, one-way. **No** watch→iPhone image path.
  - Re-queue is idempotent: on each regimen push, the iPhone re-queues every referenced-but-unconfirmed asset; the watch no-ops a write it already has.

## Output Format

A single PR containing:

- [ ] `PillImageTransfer` with `metadataKind = "pillImage"`, `metadataKindKey = "kind"`, `metadataAssetIDKey = "assetID"`.
- [ ] Producer: iPhone `transferFile(<AppGroup>/PillImages/<id>.jpg, metadata: [kind: "pillImage", assetID: <uuid>])` when `imageAssetID` is set/changed.
- [ ] Consumer: `WatchConnectivityCoordinator.session(_:didReceive file:)` branches on `metadata["kind"] == "pillImage"`, reads bytes immediately, `await PillImageStore.shared.write(data, for: assetID)`.
- [ ] Missing-asset re-queue on each regimen push for referenced-but-unconfirmed assets.
- [ ] Tests:
  - the `"pillImage"` branch does **not** regress the existing dose-batch demux (both kinds route correctly).
  - image bytes round-trip producer→consumer→`PillImageStore`.
  - a referenced asset absent on the watch is re-queued on the next regimen push.

## Examples

```swift
public enum PillImageTransfer {
  public nonisolated static let metadataKind = "pillImage"
  public nonisolated static let metadataKindKey = "kind"   // same key as dose batches
  public nonisolated static let metadataAssetIDKey = "assetID"
}
```

## Constraints

**Scope fence:** Sync transport only. **No** watch tap-through rendering (ISSUE_06), **no** PDF (ISSUE_07), **no** RxImage code. Do not add a watch→iPhone path.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator; dose-batch sync is unchanged. After adding a med with an image on the iPhone, the asset bytes land in the watch's `PillImageStore` — verifiable by the store, even though the watch UI still renders text-only (next issue).

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`, `watch`
