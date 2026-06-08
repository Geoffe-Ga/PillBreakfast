## Role

You are a senior Swift 6 strict-concurrency engineer building the on-disk asset store for pill images. It is a small `actor` that owns reads and writes of JPEG bytes in the App-Group container, usable identically on the iPhone and the watch.

## Goal

Add a `PillImageStore` actor that writes/reads/deletes ~50 KB JPEGs at `<AppGroup>/PillImages/<imageAssetID>.jpg` and can enumerate stored IDs for orphan GC. File I/O stays off the main actor. The store returns `Data` (`Sendable`); callers decode to `UIImage`/`Image`. No model, sync, or UI changes in this issue.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_01 (schema + wire). The `imageAssetID` field exists but is still unused.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.2 (asset storage), §5.5 (concurrency), §10 (testing).
- **Files involved:**
  - `Shared/Persistence/PersistenceController.swift` — reuse `appGroupIdentifier = "group.com.creekmasons.pillbreakfast"` and resolve the directory from `appGroupStoreURL`'s parent container. Do **not** store assets as SwiftData blobs (watch reads bytes directly off disk in the hot path).
  - New file under `Shared/` (e.g. `Shared/Images/PillImageStore.swift`) added to **both** target memberships (iOS app + watch app).
- **Prior decisions (locked):**
  - `actor`, not `@MainActor` — file I/O off main on both devices.
  - Files, not SwiftData external-storage blobs (keeps store small; keeps binaries out of a future CloudKit mirror #68; watch reads off disk with no fetch).
  - Atomic writes; `data(for:)` returns `nil` on a cache miss (not an error).

## Output Format

A single PR containing:

- [ ] `PillImageStore` actor with `shared` singleton, lazily-created `PillImages` directory in the App-Group container, and `write(_:for:)` / `data(for:)` / `delete(_:)` / `allStoredIDs()`.
- [ ] Tests (against a temp directory, not the real App-Group container):
  - write→read round-trip returns identical bytes.
  - `data(for:)` returns `nil` for an absent id (cache miss, not throw).
  - `delete(_:)` removes the file; subsequent `data(for:)` is `nil`.
  - `allStoredIDs()` returns exactly the written set (for orphan GC).
  - write is atomic (no partial file left on a simulated failure).

## Examples

```swift
public actor PillImageStore {
  public static let shared = PillImageStore()
  private let directory: URL  // <AppGroup>/PillImages, created lazily

  public func write(_ data: Data, for id: UUID) throws  // atomic
  public func data(for id: UUID) -> Data?               // nil = cache miss
  public func delete(_ id: UUID) throws
  public func allStoredIDs() -> Set<UUID>               // for orphan GC
}
```

## Constraints

**Scope fence:** The store only. **No** RxImage networking, **no** WC transfer, **no** UI, **no** read of `Medication.imageAssetID`. Provide a test seam (init that accepts a directory URL) so tests don't touch the real App-Group container.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; the store exists and is unit-tested but no production code path calls it yet.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`, `watch`
