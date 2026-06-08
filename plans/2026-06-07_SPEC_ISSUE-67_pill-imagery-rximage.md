# SPEC — Pill Imagery via NLM RxImage

| | |
|---|---|
| **Issue** | #67 |
| **Classification** | Future Work (SPEC §12.1) |
| **Labels** | `spec-decomposition`, `future-work`, `needs-spec` |
| **Status** | Draft |
| **Date** | 2026-06-07 |
| **Related** | Epic #11; predecessor = v1 complete (EPIC 10) and core tap-through dogfooded |

---

## 1. Summary

Add an optional pill thumbnail to each medication so the watch tap-through ritual works on **recognition, not recall**: the user sees the pill they are about to take rather than reading its name. Images are looked up once on the iPhone at medication add-time (from the NIH/NLM RxImage API), chosen by the user from 0–5 candidates, stored on-device as a small asset, and transferred to the watch via `WCSession.transferFile`. The watch **never** touches the network for images — the offline tap-through ritual is preserved. When no image exists (RxImage miss, no camera photo, or user declines), the experience degrades cleanly to today's text-only screen. PDF history export embeds the thumbnails for psychiatrist conversations.

## 2. Problem Statement / Motivation

Geoff takes ~12 pills/day. Across a dozen white-ish tablets and capsules, name-recall at the moment of dosing is exactly the failure mode the product exists to prevent. A thumbnail collapses identification to a glance. This is flagged in SPEC §12.1 as a **v1.1 high-priority follow-up**.

**Why deferred from v1:** the SPEC is explicit (§12.1, lines 540): ship and dogfood the text-only tap-through first to *confirm the at-the-moment confusion problem is real in practice*. If it is, build this out; if not, defer indefinitely. We do not want to pay the cost of a network dependency, a camera/photo permission flow, a binary-asset sync channel, and a schema migration before validating the underlying need.

## 3. Goals & Non-Goals

**Goals**
- One nullable field on `Medication` (`imageAssetID: UUID?`) referencing a locally-stored ~200×200, ~50 KB asset.
- Add-time lookup on iPhone against RxImage with a 0–5 candidate picker.
- Camera-capture fallback; name-only always remains valid (no regression to the zero-friction add flow).
- One-time per-medication binary transfer to the watch, cached locally; watch reads from disk only.
- Image-first watch tap-through when an asset is present; text-only fallback otherwise.
- Thumbnails embedded in the 30-day PDF export.
- Networking + image decode off the main actor under Swift 6 strict concurrency.

**Non-Goals**
- No image lookup or any network call on the watch, ever.
- No pill *recognition* / CV identification ("snap a mystery pill, tell me what it is"). Out of scope.
- No bulk re-lookup / backfill of existing meds in v1.1 (additive field defaults to `nil`; user can add an image by editing a med).
- No imprint/NDC-driven disambiguation UI beyond ranking hints (see §6).

## 4. Background & Current State

**Real models cited** (`Shared/Models/`):
- `Medication` (`Shared/Models/Medication.swift`) — `@Model final class`, `@Attribute(.unique) var id: UUID`, plus `displayName`, `fullName`, `unitForm`, `kind`, `colorHex`, `healthKitConceptID`, `prnAvailableQuantities`, and cascade relationships to `components`, `schedule`, `doseEvents`. **This is the model the new field lands on.**
- `DoseEvent` (`Shared/Models/DoseEvent.swift`) — carries `ingredientAmounts: [LoggedIngredientAmount]`, a denormalized snapshot "filled at log time and never recomputed." This is the precedent we mirror for the open "which image does the PDF show?" question (see §5.6).
- `LoggedIngredientAmount` (`Shared/Models/LoggedIngredientAmount.swift`) — `nonisolated struct …: Codable, Sendable, Hashable`. The pattern for any new value type that crosses the actor boundary into the detached PDF render.

**Real add-medication flow cited** (`PillBreakfast/RegimenTab/`):
- `MedicationFormView.swift` — the SwiftUI add/edit form (`Name`/`Form`/`Ingredient`/`Schedule` sections). The candidate picker and "Take a photo" affordance attach here.
- `MedicationFormState.swift` — `@MainActor @Observable final class MedicationFormState` with `apply(to:in:)`. The new `imageAssetID` draft field and its persistence land here, alongside the existing `TODO(EPIC_05_ISSUE_06)` note about deferred field persistence.

**Real sync cited** (`Shared/Sync/`):
- `WatchConnectivityCoordinator.swift` — `@MainActor @Observable` `WCSessionDelegate`. iPhone pushes the regimen via `updateApplicationContext(["regimen": data])`; the watch applies it. The reverse channel (`session(_:didReceive file:)`) already demultiplexes **file** transfers by `metadata["kind"]` (see `DoseEventBatchTransfer.metadataKind`). **The image transfer reuses this exact metadata-keyed file-transfer pattern.**
- `RegimenSnapshot.swift` — versioned (`currentSchemaVersion = 4`), additive-decode JSON wire format (`decodeIfPresent ?? default`). `MedicationDTO` is where an `imageAssetID` flag rides so the watch knows an image is *expected*.
- `DoseEventBatchTransfer.swift` — the canonical `transferFile` producer/consumer with `metadataKindKey: metadataKind`. The image transfer is a second `kind`.

**Persistence cited** (`Shared/Persistence/PersistenceController.swift`):
- `@MainActor PersistenceController` opens an App-Group `ModelContainer`; `appGroupIdentifier = "group.com.creekmasons.pillbreakfast"`; `appGroupStoreURL` resolves the shared container. **Image assets are stored as files in this App-Group container, not as SwiftData blobs** (see §5.2). The `schema` array shows the established additive-migration discipline (`SnoozeRecord`, `PillMeal` added as "lightweight migration … existing stores upgrade in place").

**PDF cited** (`PillBreakfast/HistoryTab/PDFExporter.swift`):
- `@MainActor enum PDFExporter` collects on the main actor and renders on a **detached `nonisolated` task** over `Sendable` value snapshots (`PDFDayBlockSnapshot`). Thumbnail bytes must reach the renderer as `Sendable` data, not as a live `UIImage` reference (see §5.7).

**SPEC §12.1 quoted (lines 546–556):**
> Architecture (lookup at add-time, cache forever, photo fallback): At medication add-time on iPhone, query RxImage by name and surface 0–5 candidate thumbnails. … If RxImage has no hit, offer "Take a photo." … If user declines both, name-only is always allowed. … Chosen image stored locally on iPhone as a small asset (~200×200, ~50KB) referenced by a new field on `Medication`, e.g. `imageAssetID: UUID?`. Synced to watch via `WCSession.transferFile` once per medication; cached as a local asset on the watch. **Watch never hits the network for images.**

## 5. Detailed Design

### 5.1 Schema delta & migration

One nullable field on `Medication`:

```swift
@Model
public final class Medication {
  // …existing fields…
  /// Filename-stem (UUID) of the locally-stored pill image asset, or nil for
  /// name-only meds. Never a remote URL — the asset is always on-disk in the
  /// App-Group container before this is set. Mirrors the optional-link discipline
  /// of `healthKitConceptID`: presence is the only contract, no eager fetch.
  public var imageAssetID: UUID?
}
```

**Migration:** additive, nullable — a lightweight SwiftData migration exactly like `SnoozeRecord` / `PillMeal` per `PersistenceController.schema`. Existing stores upgrade in place; legacy rows default `imageAssetID = nil`. No `VersionedSchema`/`SchemaMigrationPlan` stage is required for a single nullable scalar (confirm against the current store version at implementation time; if a `VersionedSchema` already exists, add a new version with the field).

**Wire delta:** bump `RegimenSnapshot.currentSchemaVersion` to 5 and add `imageAssetID: UUID?` to `MedicationDTO`, decoded with `decodeIfPresent` (the established pattern in `RegimenSnapshot.init(from:)`). The DTO flag tells the watch an image *should* exist; the bytes arrive on the separate file channel (§5.4). The snapshot **never** carries image bytes — `updateApplicationContext` has a tight size budget and is the wrong channel for binaries.

### 5.2 Asset storage (both devices)

Images are stored as files, **not** as SwiftData external-storage blobs. Rationale: (a) the watch consumer needs to read bytes directly off disk in the tap-through hot path without a fetch; (b) it keeps the SwiftData store small and keeps binary churn out of any future CloudKit mirror (#68); (c) it matches how the reverse-sync channel already moves files.

Layout (both targets, in the App-Group container resolved via `PersistenceController.appGroupStoreURL`'s parent):

```
<AppGroup>/PillImages/<imageAssetID>.jpg      // ~200×200, JPEG, ~50KB
```

A small `PillImageStore` actor owns reads/writes:

```swift
public actor PillImageStore {
  public static let shared = PillImageStore()
  private let directory: URL  // <AppGroup>/PillImages, created lazily

  public func write(_ data: Data, for id: UUID) throws { /* atomic write */ }
  public func data(for id: UUID) -> Data?               // nil = cache miss
  public func delete(_ id: UUID) throws
  public func allStoredIDs() -> Set<UUID>               // for orphan GC
}
```

An `actor` (not `@MainActor`) so file I/O stays off the main actor on both devices. Returns `Data` (`Sendable`), decoded to `UIImage`/`Image` at the call site.

### 5.3 RxImage API contract (iPhone only)

- **Base:** `https://rximage.nlm.nih.gov/api/rximage/1/rxnav`
- **Auth:** none (free, public US-government data; attribution-only license).
- **Primary query:** by name. Example: `…/rxnav?name=gabapentin&resolution=600`. The response is JSON containing a `nlmRxImages` array; each entry exposes an image URL plus metadata (`imprint`, `splColor`/`color`, `splShape`/`shape`, `ndc11`, `rxcui`, `name`).
- **Ranking inputs available:** name match, imprint, color, shape, NDC. v1.1 ranks by name-match quality and caps the surfaced set at **5**; color/shape are shown as captions to help the user disambiguate, not used as filters initially (the dataset is sparse — over-filtering produces zero hits).
- **Thumbnail fetch:** each candidate's image URL is fetched, downscaled to ~200×200, re-encoded JPEG at ~50 KB. Original lab images are large; we never store the original.

A `RxImageClient` encapsulates this:

```swift
public struct RxImageCandidate: Sendable, Hashable {
  public let imageURL: URL
  public let imprint: String?
  public let color: String?
  public let shape: String?
  public let ndc11: String?
}

public protocol RxImageClient: Sendable {
  /// Returns 0–5 ranked candidates. Empty array = no hit (expected, not an error).
  func candidates(forName name: String) async throws -> [RxImageCandidate]
  /// Fetches + downscales a chosen candidate to the ~200×200 / ~50KB asset bytes.
  func thumbnailData(for candidate: RxImageCandidate) async throws -> Data
}
```

`Sendable` protocol so it can be injected into the `@MainActor` form layer and called with `await`. A `URLSessionRxImageClient` is the production conformance; tests inject a stub returning fixtures (no network in CI).

### 5.4 WC image transfer flow

Reuse the `metadata["kind"]`-keyed file-transfer pattern from `DoseEventBatchTransfer`:

```swift
public enum PillImageTransfer {
  public nonisolated static let metadataKind = "pillImage"
  public nonisolated static let metadataKindKey = "kind"   // same key as dose batches
  public nonisolated static let metadataAssetIDKey = "assetID"
}
```

- **Producer (iPhone):** when a med's `imageAssetID` is first set (or changed), call `WCSession.transferFile(<AppGroup>/PillImages/<id>.jpg, metadata: [kind: "pillImage", assetID: <uuid>])`. `transferFile` queues until the watch is reachable, surviving an asleep watch (same guarantee the dose channel relies on).
- **Consumer (watch):** extend `WatchConnectivityCoordinator.session(_:didReceive file:)` to branch on `metadata["kind"]`. For `"pillImage"`, read the file bytes (the URL is valid only during the call — read immediately, exactly like the dose path does), then `await PillImageStore.shared.write(data, for: assetID)`.
- **Reconciliation on regimen apply:** when the watch applies a `RegimenSnapshot` whose `MedicationDTO.imageAssetID` is set but `PillImageStore` has no bytes for it, the watch is missing an asset (e.g. it was offline for the transfer). The watch records the gap; the iPhone re-sends any asset whose ID is referenced by the current regimen but was never ACK'd. Simplest robust approach: on each regimen push, the iPhone also (idempotently) re-queues `transferFile` for every referenced asset the watch hasn't confirmed. `transferFile` is cheap when the file is unchanged and the watch can no-op a write it already has.

**Authority:** images follow the existing **iPhone-authoritative, one-way** model. The iPhone owns the asset (camera or RxImage); the watch is a read-only cache. There is no watch→iPhone image path.

### 5.5 Concurrency model (Swift 6 strict)

- Networking + decode (`RxImageClient`) is `async`/`Sendable`; never on the main actor. Downscale/re-encode runs inside the client's async functions (off-main).
- Disk I/O via the `PillImageStore` **actor**.
- The form layer (`MedicationFormState`, `@MainActor @Observable`) `await`s the client and store; only the final `Data`→`UIImage` for preview, and the `imageAssetID` write, happen on the main actor.
- The PDF renderer is `nonisolated` and detached; it receives thumbnail **bytes** (`Data`, `Sendable`) inside the snapshot, never a live image object.
- **No `@unchecked Sendable`, no force-unwraps to silence optionals, no `try?`-swallowing.** A network failure surfaces as "couldn't load suggestions — add a photo or skip"; a decode failure is logged and treated as a miss.

### 5.6 Open design point — image immutability vs. live reference

Per the issue's own open question: when a user later changes a med's `imageAssetID`, should the PDF re-embed the new image, or should each `DoseEvent` pin the image in place at log time (mirroring the `ingredientAmounts` denormalization)?

**Recommendation:** the watch tap-through and Regimen views read the *live* `Medication.imageAssetID` (you want the current pill picture when taking the current pill). The **PDF history** is a record of what was taken; the strongest consistency story is to denormalize a `loggedImageAssetID: UUID?` onto `DoseEvent` at log time, exactly as `ingredientAmounts` is denormalized, so a re-photographed med doesn't rewrite a historical export. This is a deliberate, recorded mirror of the §5.3 denormalization rule. **Defer the final call to grooming**, but the recommended default is: live reference for the ritual, denormalized snapshot for history. If we adopt the snapshot, it is a second additive nullable `DoseEvent` field plus an additive `DoseEventDTO` field (decoded with `decodeIfPresent`).

### 5.7 PDF thumbnail embed

`PDFExporter.collectBlocks` (MainActor) resolves, per `.taken` event, the relevant `imageAssetID` (live or denormalized per §5.6), reads bytes via `PillImageStore`, and packs them into the `Sendable` `PDFDayBlockSnapshot`/row snapshot as `Data?`. The detached `nonisolated render` draws them with `UIImage(data:)` → `draw(in:)`. No live model or `UIImage` crosses the detach boundary — only `Data`, preserving the existing isolation seam.

## 6. Alternatives Considered

| Decision | Options | Verdict |
|---|---|---|
| Image source | RxImage (NLM) / scrape drugs.com / ship a bundled set / user-photo-only | **RxImage.** Free, no-auth, government data, attribution-only; the upstream source the commercial sites use. Scraping = ToS + brittleness. Bundled set can't cover an arbitrary regimen. Photo-only loses the zero-typing win for common generics. |
| Asset storage | File in App-Group container / SwiftData external-storage attribute / Asset Catalog | **File in App-Group.** Watch reads bytes off disk in the hot path with no fetch; keeps the store small; keeps binaries out of a future CloudKit mirror (#68). |
| Watch image delivery | `transferFile` (reuse dose channel) / embed in `updateApplicationContext` / watch fetches RxImage directly | **`transferFile`.** Context is size-constrained and wrong for binaries; watch-direct fetch violates the hard offline-ritual rule (SPEC §12.1). |
| Lookup timing | At add-time (cache forever) / lazily on first display / nightly background refresh | **Add-time.** Matches SPEC §12.1; lookup happens where the user already has context and a keyboard; nothing in the dosing hot path ever blocks on a network. |
| PDF image source | Live `Medication.imageAssetID` / denormalized per-`DoseEvent` snapshot | **Denormalized snapshot recommended** (mirrors `ingredientAmounts`); final call deferred to grooming. |
| Candidate disambiguation | Name only / name+imprint+color+shape filter / NDC exact | **Name query + color/shape as captions** for v1.1. The C3PI dataset is sparse; aggressive filtering yields zero hits. NDC exact is a later enhancement once HealthKit import supplies an NDC. |

## 7. UX & Visual Design

- **Add flow (iPhone, `MedicationFormView`):** after a name is entered, an "Add pill image" row offers (a) auto-suggested RxImage candidates in a horizontally-scrolling Liquid-Glass card strip (0–5 thumbnails with color/shape/imprint captions), (b) "Take a photo," (c) "Skip — name only." Selecting a candidate fetches + stores the asset and sets `imageAssetID`. **The flow is fully skippable**; a med with no image saves normally (no regression to the zero-friction path).
- **Watch tap-through (`MarkTakenView`):** when an asset exists, the hero card becomes image-first — the thumbnail sits above/inline with the name in the existing hero `VStack`, replacing nothing (name stays for accessibility/VoiceOver). When `imageAssetID == nil`, the view renders exactly as today. The image is loaded once from `PillImageStore` when the queue screen appears; **no network**.
- **Liquid Glass:** the candidate strip and the watch thumbnail sit on the existing `LiquidGlassTheme.Materials.surface` card. **Color discipline preserved** — the photographed pill carries its own colors, but no chrome/accent color is introduced; amber remains reserved for high-risk press-and-hold.
- **Offline-ritual rule (hard):** the watch tap-through must render identically whether or not the network exists. Asset present → image; absent → text. Never a spinner, never a fetch.

## 8. Edge Cases & Graceful Degradation

- **RxImage miss** (expected — C3PI discontinued 2018; supplements/newer manufacturers/many OTCs absent): zero candidates → straight to "Take a photo / Skip." Treated as normal, not an error.
- **Network down at add-time:** suggestions area shows "Couldn't load suggestions" with photo/skip still available. Med saves fine.
- **Watch missing asset** (offline during transfer): tap-through falls back to text; iPhone re-queues transfer on next regimen push (§5.4).
- **Asset orphaned** (med archived/deleted, or image replaced): a GC pass compares `PillImageStore.allStoredIDs()` against live `imageAssetID`s (and any denormalized `DoseEvent` references) and deletes unreferenced files. Run on iPhone after archive/edit; on watch after each regimen apply.
- **Corrupt/oversized image:** decode failure logged, treated as a miss; never crashes the renderer or the ritual.
- **Camera/photo permission denied:** surface the system prompt path once; if denied, fall back to name-only. Permission strings (`NSCameraUsageDescription`) added to the iOS target Info.plist.
- **Re-import / duplicate med:** new med = new `imageAssetID`; no dedup of identical pills across products (acceptable; ~50 KB each).

## 9. Privacy, Security & Compliance

- RxImage is anonymous reference data; queries send a **medication name** to an NLM endpoint. This is a (mild) PHI disclosure — a network call that reveals a medication the user takes. **Document it in the privacy nutrition label and an in-app disclosure**, and make the lookup opt-in per add (it already is — the suggestion strip is an explicit affordance; consider a one-time "look up pill images?" consent on first use).
- Camera photos never leave the device except via the existing WC channel to the user's own paired watch.
- Attribution: NLM RxImage/RxNav requires source attribution. Add an attribution line in Settings → About and in the PDF footer band (alongside the existing seeded-ingredient disclaimer drawn by `PDFExporter.drawFooter`).
- No third-party analytics on image data.

## 10. Testing Strategy

- `RxImageClient` against **recorded fixtures** (no live network in CI): ranking, 0-candidate handling, malformed JSON → miss.
- Downscale/re-encode produces ≤ ~50 KB, ~200×200.
- `PillImageStore` actor: write/read/delete/orphan-GC round-trips in a temp directory.
- WC transfer: `metadata["kind"]` demux doesn't regress the existing dose-batch path; image bytes round-trip; missing-asset re-queue.
- `RegimenSnapshot` v5: `imageAssetID` survives encode→decode; **v4 and earlier payloads still decode** (`decodeIfPresent` default).
- Migration: a store with `imageAssetID`-less rows opens and defaults to `nil`.
- Watch tap-through snapshot tests: image-present vs. name-only render; offline never shows a spinner.
- PDF: thumbnail embed renders; missing image falls back to text row; detached renderer receives only `Sendable` `Data`.
- VoiceOver: image-first screen still announces the medication name + dose.

## 11. Risks & Open Questions

- **Dataset coverage** is the headline risk — but it's a graceful-degradation problem, not a blocker (SPEC §12.1).
- **Final immutability decision** (§5.6) — confirm at grooming.
- **Watch cache policy** (issue open question): LRU vs. hard cap. Recommendation: keep every referenced asset (the active regimen is small — a dozen meds × 50 KB ≈ 600 KB); GC only orphans. Revisit only if a user's regimen grows pathologically.
- **RxImage endpoint longevity** — government endpoint, discontinued upstream project. If it disappears, the photo fallback fully covers the feature; consider snapshotting fixtures for the seeded ingredient set.
- **Consent UX** for the name-leaving-device disclosure — confirm copy with the privacy review.

## 12. Decomposition Hints (post-v1, tracer-code order)

1. Schema + migration: add `Medication.imageAssetID`; bump `RegimenSnapshot` to v5 with `decodeIfPresent`; tests for migration + wire compat. *(End-to-end stays green; field unused.)*
2. `PillImageStore` actor + App-Group directory; unit tests.
3. `RxImageClient` protocol + `URLSessionRxImageClient` + fixtures; ranking/decode tests. *(Pure, no UI.)*
4. iPhone add-flow UI: candidate strip + photo + skip in `MedicationFormView`/`MedicationFormState`; permission strings.
5. WC `pillImage` transfer: producer on iPhone, consumer branch in `WatchConnectivityCoordinator`; missing-asset re-queue.
6. Watch tap-through image-first branch in `MarkTakenView`; offline-render tests.
7. (If adopted) `DoseEvent.loggedImageAssetID` denormalization + DTO field.
8. PDF thumbnail embed in `PDFExporter` snapshot + detached render.
9. Orphan GC; attribution + privacy disclosure; nutrition-label delta.

## 13. Acceptance Criteria / Done-Done

- A med can be added with a chosen RxImage thumbnail, a camera photo, or no image — all three save and sync.
- The watch tap-through shows the image when present and is byte-for-byte the current text-only screen when absent; **no network call on the watch under any path** (verified by a no-network device test).
- Editing an image on the iPhone updates the watch within the normal sync window.
- The 30-day PDF embeds thumbnails and remains readable after email.
- `RegimenSnapshot` v4 payloads still decode on a v5 build.
- Privacy nutrition label + in-app disclosure + NLM attribution shipped.
- No anti-bypass violations (no `@unchecked Sendable`, force-unwrap-to-silence, `try?`-swallow, or lint disables).

## 14. References

- `plans/SPEC.md` §12.1 (lines 540–556), §5.2/§5.3 (denormalization precedent), §7.2 (tap-through), §3 (HealthKit constraint).
- Code: `Shared/Models/Medication.swift`, `Shared/Models/DoseEvent.swift`, `Shared/Models/LoggedIngredientAmount.swift`, `Shared/Sync/WatchConnectivityCoordinator.swift`, `Shared/Sync/RegimenSnapshot.swift`, `Shared/Sync/DoseEventBatchTransfer.swift`, `Shared/Persistence/PersistenceController.swift`, `PillBreakfast/RegimenTab/MedicationFormView.swift`, `PillBreakfast/RegimenTab/MedicationFormState.swift`, `PillBreakfast/HistoryTab/PDFExporter.swift`, `PillBreakfast Watch App Watch App/TapThroughQueue/MarkTakenView.swift`.
- NLM RxImage / RxNav: `https://rximage.nlm.nih.gov/api/rximage/1/rxnav`; C3PI (discontinued 2018).
- Apple: `WatchConnectivity` (`transferFile`), `SwiftData` lightweight migration, `URLSession`, `UIGraphicsPDFRenderer`.
- Issues: #67, epic #11.
