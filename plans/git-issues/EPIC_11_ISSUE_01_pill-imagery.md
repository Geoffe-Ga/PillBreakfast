## Role

Placeholder — **v1.1 high-priority follow-up**, not ready to pick up. Groom into a real issue (or its own epic) once v1 is dogfooded; see Open Questions before assigning.

## Goal

Display a thumbnail of the actual pill on each watch tap-through screen so the dose ritual works on recognition, not recall — faster, less mental work, and fewer mix-ups across a ~12-pill regimen. The watch tap-through screen becomes image-first when an asset is available and falls back to text-only when not; PDF export embeds thumbnails for psychiatrist conversations.

Deliberately deferred to **v1.1**: ship and dogfood the core text-only tap-through first to confirm the at-the-moment confusion problem is real. If it is, build this out as described; if not, defer indefinitely.

## Context

- **Parent epic:** #11
- **Predecessor:** v1 complete (full EPIC 10) and the core tap-through validated in real use.
- **SPEC section:** `plans/SPEC.md` §12.1 (lines 540-556).

### Image source — NLM RxImage API

- Endpoint: `https://rximage.nlm.nih.gov/api/rximage/1/rxnav` — free, public, no-auth REST.
- Data: JPEGs photographed under lab lighting with metadata (color, shape, imprint, NDC). US government data, attribution-only license.
- This is the dataset drugs.com, WebMD, and GoodRx all build on; going direct to the source avoids ToS issues and brittle scraping.

### Known limitation — graceful degradation, not a blocker

The underlying C3PI project was discontinued in 2018. The API and existing data remain available, but no new pills have been added since. Established generics (lithium, gabapentin) are well-covered; newer manufacturers, supplements, and many OTCs may be absent. The architecture below treats a miss as expected, not exceptional.

### Architecture — lookup at add-time, cache forever, photo fallback

- At medication add-time on iPhone, query RxImage by name and surface 0–5 candidate thumbnails; user taps the right one.
- If RxImage has no hit, offer "Take a photo" — snap the pill with the iPhone camera.
- If the user declines both, name-only is always allowed (preserves the v1 zero-friction add flow).
- Chosen image stored locally on iPhone as a small asset (~200×200, ~50KB) referenced by a new field on `Medication`, e.g. `imageAssetID: UUID?`.
- Synced to the watch via `WCSession.transferFile` once per medication; cached as a local asset on the watch.
- The watch never hits the network for images — the tap-through ritual stays fully offline.

- **Files this will touch (preview):** `Shared/Models/Medication.swift` (new `imageAssetID: UUID?`); `iOSApp/RegimenTab/RxImageLookupView.swift` (new); `WatchApp/TapThroughQueue/MarkTakenView.swift` (image branch); `iOSApp/HistoryTab` PDF export (thumbnail embed).
- **Schema migration:** one nullable field on `Medication`. Trivial v1.1 migration.

### Open questions (needs-spec — resolve before promoting from placeholder)

- Image cache policy on the watch (LRU? hard size cap?).
- When the user later changes a `Medication.imageAssetID`, does the PDF re-embed the new image, or does each `DoseEvent` keep a reference to the asset in place at log time? Likely the latter, mirroring the `ingredientAmounts` denormalization pattern — confirm before filing.
- Photo-library / camera permission flow when the user falls back to "Take a photo."
- RxImage query strategy: match on name vs. NDC vs. imprint, and how to rank 0–5 candidates.

## Output Format

Per the SPEC §12.1 architecture above. To be sharpened into a real epic or child issue before promoting from placeholder.

## Constraints

**Watch never hits the network.** Images are pre-transferred via `WCSession.transferFile` and cached locally. SPEC §12.1.

**Name-only must remain frictionless.** RxImage lookup and photo capture are both optional; a medication added with no image is fully valid. Do not regress the v1 zero-friction add flow.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

## Definition of Done (stay-green)

Not applicable until the placeholder is groomed into a real issue.

## Labels

`spec-decomposition`, `future-work`, `needs-spec`.
