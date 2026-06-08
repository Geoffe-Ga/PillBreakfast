## Role

You are a senior Swift 6 strict-concurrency engineer building the NLM RxImage lookup client. It is a pure, injectable, off-main networking + image-decode component with no UI. All network access in tests is replaced by recorded fixtures.

## Goal

Add an `RxImageClient` protocol and a `URLSessionRxImageClient` production conformance that (a) queries RxImage by medication name and returns 0–5 ranked candidates and (b) fetches a chosen candidate's image, downscales it to ~200×200, and re-encodes JPEG at ~50 KB. Networking and decode run off the main actor. Zero candidates is a normal result, not an error.

## Context

- **Parent epic:** #67
- **Predecessors:** ISSUE_01 (schema/wire) and ISSUE_02 (`PillImageStore`). This issue produces the bytes the store will hold, but does not itself write to the store (the form layer in ISSUE_04 wires them).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` §5.3 (RxImage API contract), §5.5 (concurrency), §6 (candidate disambiguation), §10 (testing).
- **Files involved:**
  - New files under `Shared/` or the iOS target (e.g. `PillBreakfast/RxImage/RxImageClient.swift`). **iPhone-only** — never compiled into or called from the watch target.
  - Test fixtures (recorded JSON + a small image) under the iOS test target; **no live network in CI**.
- **Prior decisions (locked):**
  - Base: `https://rximage.nlm.nih.gov/api/rximage/1/rxnav`; no auth (public US-government data; attribution-only license).
  - Rank by name-match quality; cap the surfaced set at **5**; color/shape/imprint shown as captions, not filters (the C3PI dataset is sparse — over-filtering yields zero hits).
  - Downscale to ~200×200, re-encode JPEG ~50 KB; never store the original lab image.
  - `Sendable` protocol so it injects into the `@MainActor` form layer and is `await`ed.

## Output Format

A single PR containing:

- [ ] `RxImageCandidate: Sendable, Hashable` (imageURL, imprint?, color?, shape?, ndc11?).
- [ ] `RxImageClient: Sendable` protocol: `candidates(forName:) async throws -> [RxImageCandidate]` (0–5; empty = no hit) and `thumbnailData(for:) async throws -> Data` (downscaled/re-encoded).
- [ ] `URLSessionRxImageClient` production conformance; networking + decode off main.
- [ ] Tests against recorded fixtures:
  - well-formed response → ranked candidates, capped at 5.
  - empty `nlmRxImages` → `[]` (miss, not throw).
  - malformed JSON → treated as a miss (logged), not a crash.
  - `thumbnailData(for:)` output is ≤ ~50 KB and ~200×200.

## Examples

```swift
public struct RxImageCandidate: Sendable, Hashable {
  public let imageURL: URL
  public let imprint: String?
  public let color: String?
  public let shape: String?
  public let ndc11: String?
}

public protocol RxImageClient: Sendable {
  func candidates(forName name: String) async throws -> [RxImageCandidate]
  func thumbnailData(for candidate: RxImageCandidate) async throws -> Data
}
```

## Constraints

**Scope fence:** The client + fixtures only. **No** UI, **no** writes to `PillImageStore`, **no** WC, **no** watch code. The client must be injectable so production wiring is deferred to ISSUE_04.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; the client is unit-tested in isolation and not yet invoked by any UI. The watch target does not link the client and makes no network call.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #67`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
