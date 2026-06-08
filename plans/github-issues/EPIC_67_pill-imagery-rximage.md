# Epic — #67: Pill imagery via NLM RxImage

## Epic Summary

Add an optional pill thumbnail to each medication so the watch tap-through ritual works on **recognition, not recall** — the user sees the pill they are about to take rather than reading its name. Images are looked up once on the iPhone at medication add-time (NIH/NLM RxImage API), chosen from 0–5 candidates, downscaled to a ~200×200 / ~50 KB on-disk asset, and transferred to the watch via `WCSession.transferFile`. The watch **never** touches the network for images — the offline tap-through ritual is preserved byte-for-byte. When no image exists (RxImage miss, no camera photo, or user declines), the experience degrades cleanly to today's text-only screen. The 30-day PDF history export embeds the thumbnails.

This is post-v1 follow-up work (SPEC §12.1, flagged as a v1.1 high-priority item gated on dogfooding the text-only ritual first). All children carry `future-work` so the Ralph picker parks them.

## Scope

**In:**
- One nullable field `Medication.imageAssetID: UUID?` + additive lightweight migration; `RegimenSnapshot` bumped to v5 with `decodeIfPresent`.
- `PillImageStore` actor owning reads/writes in the App-Group `PillImages/` directory (both targets).
- `RxImageClient` protocol + `URLSessionRxImageClient` (iPhone only), with fixture-backed tests and off-main networking/decode.
- iPhone add-flow UI: 0–5 candidate strip + camera capture + "Skip — name only" in `MedicationFormView`/`MedicationFormState`; `NSCameraUsageDescription`.
- WC `pillImage` file transfer: producer on iPhone, consumer branch in `WatchConnectivityCoordinator`; missing-asset re-queue on regimen push.
- Watch tap-through image-first branch in `MarkTakenView`; offline-render tests.
- PDF thumbnail embed in `PDFExporter` snapshot + detached render; NLM attribution; orphan GC; privacy disclosure + nutrition-label delta.

**Out:**
- Any network call on the watch, ever (hard rule, SPEC §12.1).
- Pill *recognition* / CV identification ("snap a mystery pill, name it").
- Bulk re-lookup / backfill of existing meds (additive field defaults to `nil`; user adds by editing a med).
- Imprint/NDC-driven disambiguation UI beyond ranking captions.

## Success Criteria

- A med can be added with a chosen RxImage thumbnail, a camera photo, or no image — all three save and sync.
- The watch tap-through shows the image when present and is byte-for-byte the current text-only screen when absent; **no network call on the watch under any path** (verified by a no-network device test).
- Editing an image on the iPhone updates the watch within the normal sync window.
- The 30-day PDF embeds thumbnails and remains readable after email.
- `RegimenSnapshot` v4 payloads still decode on a v5 build.
- Privacy nutrition label + in-app disclosure + NLM attribution shipped.
- No anti-bypass violations (no `@unchecked Sendable`, force-unwrap-to-silence, `try?`-swallow, or lint disables).

## Child Issues

- [ ] **Skeleton** — `EPIC_67_ISSUE_01_schema-and-wire.md`: add `Medication.imageAssetID`; lightweight migration; bump `RegimenSnapshot` to v5 + `MedicationDTO.imageAssetID` with `decodeIfPresent`. Field unused everywhere; end-to-end stays green; v4 payloads still decode.
- [ ] **Core** — `EPIC_67_ISSUE_02_pill-image-store.md`: `PillImageStore` actor + App-Group `PillImages/` directory; write/read/delete/`allStoredIDs` round-trips in a temp dir. Pure, no UI.
- [ ] **Core** — `EPIC_67_ISSUE_03_rximage-client.md`: `RxImageClient` protocol + `URLSessionRxImageClient` + recorded fixtures; ranking, 0-candidate handling, malformed-JSON→miss, downscale/re-encode ≤ ~50 KB. Off-main; no UI.
- [ ] **Core** — `EPIC_67_ISSUE_04_iphone-add-flow.md`: candidate strip + "Take a photo" + "Skip — name only" in `MedicationFormView`/`MedicationFormState`; `NSCameraUsageDescription`. Wires client + store; sets `imageAssetID`.
- [ ] **Core** — `EPIC_67_ISSUE_05_wc-image-transfer.md`: `PillImageTransfer` metadata; iPhone producer; `WatchConnectivityCoordinator` consumer branch on `metadata["kind"]`; missing-asset re-queue on regimen push.
- [ ] **Core** — `EPIC_67_ISSUE_06_watch-tap-through.md`: image-first branch in `MarkTakenView` reading `PillImageStore` from disk; offline-render snapshot tests (never a spinner); VoiceOver still announces name + dose.
- [ ] **Polish** — `EPIC_67_ISSUE_07_pdf-orphan-gc-attribution.md`: PDF thumbnail embed (optional `DoseEvent.loggedImageAssetID` denormalization per §5.6, deferred default = live reference); orphan GC; NLM attribution; privacy disclosure + nutrition-label delta.

## Sequencing Notes

Children are strictly ordered skeleton → stores/client → UI → sync → watch → polish. ISSUE_02 and ISSUE_03 both depend only on ISSUE_01 and are independent of each other, but file them in number order; ISSUE_04 depends on both. ISSUE_05 depends on ISSUE_01 (wire flag) + ISSUE_02 (store). ISSUE_06 depends on ISSUE_02 + ISSUE_05. ISSUE_07 depends on ISSUE_02 (and on the §5.6 immutability decision, deferred to grooming — default to live reference, adopt `DoseEvent.loggedImageAssetID` only if grooming says so). Each child's Context names its predecessor. The whole epic is a child of phase-epic **#11** (Future Work Placeholders) and the existing issue **#67** is its parent epic. It precedes nothing; it is gated on v1 being complete and the text-only tap-through dogfooded.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-67_pill-imagery-rximage.md` (full design). SPEC §12.1 (lines 540–556), §5.2/§5.3 (denormalization precedent), §7.2 (tap-through), §3 (HealthKit constraint).

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`, `watch`
