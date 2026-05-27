# EPIC 07 — Phase 6: HealthKit One-Tap Onboarding Import

## Epic Summary

First-run users with existing medications in Apple Health can onboard in one tap. On the iPhone, PillBreakfast requests per-medication read authorization, queries `HKUserAnnotatedMedication`, presents an import sheet, and maps each chosen Health medication onto a PillBreakfast `Medication` — preserving `healthKitConceptID` for future read-back enrichment. Re-running the import is idempotent: existing medications matched by `healthKitConceptID` are skipped. Implements SPEC §10 Phase 6 (lines 470-478) and the §3.3 import-only architecture.

## Scope

**In scope:**

- iPhone HealthKit authorization flow with **per-medication read scope** (the deliberately confusing API path from SPEC §11). User-facing copy must explain what is read and that PillBreakfast never writes to Health.
- `HealthKitImportService` actor (iOS only) that queries `HKUserAnnotatedMedication` and surfaces the result set in an `ImportSheet` SwiftUI view.
- Mapping layer that converts a `HKUserAnnotatedMedication` to a draft PillBreakfast `Medication`: name -> `displayName`, scheduled times -> `ScheduledDose[]`, the Health concept identifier -> `healthKitConceptID`.
- **Manual ingredient confirmation step:** Health does not expose composition reliably (SPEC §6.1), so each imported product surfaces a "Confirm the active ingredients" screen using the seeded ingredient library from EPIC 02. Single-ingredient products auto-fill the obvious match; combos are user-confirmed.
- **Idempotent re-import:** queries the SwiftData store for an existing `Medication` with the same `healthKitConceptID` and skips duplicates. Updating quantities or schedule on re-import is **not** in scope — that's future work (SPEC §12 item 4, "Health dose readback enrichment").
- Privacy nutrition disclosure copy stub in the Settings tab (full disclosure ships in EPIC 10).
- Unit tests for the mapping layer (Health DTO -> PillBreakfast draft `Medication`) and for re-import idempotency keyed on `healthKitConceptID`.
- Compile-time isolation: every HealthKit Medications API call lives in iOS-only files (e.g. `iOSApp/HealthKitImport/`). The watch target must not import these files or symbols.

**Out of scope:**

- **Writing to HealthKit Medications.** Not possible — third-party apps cannot write (SPEC §3.2, confirmed by Apple DTS). The import is strictly read-only.
- **Watch access to HealthKit Medications.** Not possible — the API is iOS/iPadOS/visionOS only (SPEC §3.2). The watch reads the synced `Medication` rows from SwiftData via the existing `WCSession` channel, not from Health.
- **Health dose readback enrichment** (SPEC §12 future work item 4): detecting that the user logged a dose in Health's own UI and avoiding a double-prompt. Defer to v1.1.
- Updating a previously-imported medication on re-run (no merge semantics in v1).

## Critical Architecture (carry into every child issue)

- **HealthKit Medications is read-only and iOS-only.** SPEC §3 and CLAUDE.md are explicit. Any PR that proposes a write path or a watch import path must be rejected. This is the single most-likely architectural mistake; call it out in the PR template.
- **Health is an onboarding import source, not the source of truth.** PillBreakfast's SwiftData store is authoritative. After import, the user can edit the imported medication freely and Health is not re-consulted.
- **`healthKitConceptID` is the dedupe key.** A medication without one was added manually; a medication with one came from Health. Do not derive the field from name matching; that creates false positives across brand/generic pairs.
- **Per-medication authorization is deliberate, not a bug.** The user is supposed to choose which Health medications PillBreakfast can see. If a medication the user previously authorized is later revoked, the import sheet must handle the "no results" case gracefully and prompt the user back to Settings.

## Success Criteria

The epic is done when:

- [ ] On the iPhone simulator (or device), setting up Lithium in Apple Health, then installing PillBreakfast and tapping "Import from Apple Health" pulls it in without re-typing the name or schedule. Confirming the ingredient component is the only manual step.
- [ ] Running the import flow again does not create a duplicate `Medication` for Lithium.
- [ ] The watch target compiles and links without seeing any HealthKit Medications symbols.
- [ ] HealthKit authorization is requested per-medication, not all-at-once, and the denial path shows a meaningful empty state.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #NNN — Skeleton: Add the "Import from Apple Health" entry point to the iPhone Regimen tab with a stub sheet, plus HealthKit capability + Info.plist usage strings (EPIC_07_ISSUE_01).
- [ ] #NNN — Implement HealthKit per-medication read authorization in `HealthKitImportService`, iOS-only file boundary (EPIC_07_ISSUE_02).
- [ ] #NNN — Query `HKUserAnnotatedMedication` and surface results in the import sheet with selection state (EPIC_07_ISSUE_03).
- [ ] #NNN — Map Health DTOs to PillBreakfast draft `Medication`s preserving `healthKitConceptID` and surfacing a manual ingredient confirmation step (EPIC_07_ISSUE_04).
- [ ] #NNN — Idempotent re-import keyed on `healthKitConceptID` with unit tests (EPIC_07_ISSUE_05).

## Sequencing Notes

- **Depends on:** EPIC 02 (data model, `healthKitConceptID` field, seeded ingredient library).
- **Unblocks:** Nothing strictly — onboarding can land any time after the manual add path exists.
- **Parallel-safe:** EPIC 05, EPIC 06, EPIC 08 are all independent surfaces.

## SPEC Reference

`plans/SPEC.md` §3 (the entire HealthKit constraint discussion, lines 57-94), §6.1 (Add Medication flow, "Import from Apple Health"), §10 Phase 6 (lines 470-478), §11 (Phase 6 skill callout: per-object HealthKit authorization).

## Labels

`epic`, `spec-decomposition`, `phase-6-healthkit`, `tracer-code`.
