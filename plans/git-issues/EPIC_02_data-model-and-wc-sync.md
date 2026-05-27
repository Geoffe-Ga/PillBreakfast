# EPIC 02 — Phase 1: Data Model & WatchConnectivity Sync Tracer

## Epic Summary

Land the SwiftData schema from SPEC §5 verbatim, then prove one end-to-end round-trip: seed a hardcoded "Stub Lithium 300mg, daily 8am" medication on iPhone, push it to the watch via `WCSession.updateApplicationContext`, and render its name on the watch. This is the first issue where the system carries actual product data, and it sets the contracts every later epic builds on. Implements SPEC §10 Phase 1 (lines 409-419) and the entire data model from SPEC §5.

## Scope

**In scope:**

- All `@Model` classes from SPEC §5.2 in `Shared/Models/`: `Ingredient`, `MedicationComponent`, `Medication`, `ScheduledDose`, `DoseEvent`, plus the `LoggedIngredientAmount` struct and the enums (`MedicationKind`, `MedicationForm`, `DoseStatus`, `LogSource`).
- The denormalized snapshot pattern on `DoseEvent.ingredientAmounts` from SPEC §5.3 — non-negotiable, see "Critical Architecture" below.
- `Sendable` conformance and Swift 6 strict-concurrency review for the model graph.
- The seeded ingredient library from SPEC §5.3 (Acetaminophen, Ibuprofen, Aspirin, Naproxen, Diphenhydramine, Caffeine) with suggested-default ceilings and a clear "you are responsible for confirming with your prescriber" disclaimer in the seed comment.
- A `RegimenSnapshot: Codable, Sendable` DTO for crossing the WatchConnectivity boundary (do not serialize `@Model` classes directly).
- iPhone-side seed of one hardcoded medication and one `ScheduledDose`.
- WatchConnectivity round-trip via `updateApplicationContext`: iPhone encodes the snapshot, watch decodes and renders the medication name on a placeholder list view.
- Unit tests for ingredient seeding idempotency and for `RegimenSnapshot` Codable round-trip.

**Out of scope:**

- Editing UI (EPIC 03).
- `DoseEvent` reverse sync via file transfer (EPIC 03).
- Notifications (EPIC 03).
- PRN safety logic — `violationsIfTaken`, `totalToday`, `lastDoseTime` (EPIC 05).

## Critical Architecture (carry into every child issue)

- **Denormalize ingredient amounts at log time.** `DoseEvent.ingredientAmounts: [LoggedIngredientAmount]` is filled when the dose is recorded, never recomputed from the live `Medication.components`. This is what makes editing a product's composition later not retroactively rewrite history, and what keeps watch running-total queries fast. See SPEC §5.3 and CLAUDE.md.
- **`isHighRisk` lives on `Ingredient`, not on `Medication`.** `Medication.isHighRisk` is a computed property that returns `components.contains { $0.ingredient?.isHighRisk == true }`. Do not add a stored boolean on `Medication`.
- **`healthKitConceptID` is populated only on Health-imported meds.** It's a future read-back hint, not a write channel. EPIC 07 sets it; this epic must keep the field but never populate it.
- **Watch never reads HealthKit Medications.** That API is iOS/iPadOS/visionOS only.

## Success Criteria

The epic is done when:

- [ ] The `@Model` graph compiles under Swift 6 strict concurrency without `@unchecked Sendable`.
- [ ] First-launch on iPhone seeds the ingredient library; relaunch does not duplicate seeds (idempotent).
- [ ] Editing the stub medication's `displayName` on iPhone causes the new name to appear on the watch within 5 seconds (SPEC §10 Phase 1 gate).
- [ ] `RegimenSnapshot` round-trips Codable in unit tests and across the real `WCSession` boundary.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #NNN — Skeleton: Add `Shared/Models/` with empty `@Model` classes wired into the container (EPIC_02_ISSUE_01).
- [ ] #NNN — Implement the schema body from SPEC §5.2 with `Sendable` review and unit tests (EPIC_02_ISSUE_02).
- [ ] #NNN — Add the seeded ingredient library with idempotent first-launch insertion (EPIC_02_ISSUE_03).
- [ ] #NNN — Add `RegimenSnapshot` DTO + Codable round-trip tests (EPIC_02_ISSUE_04).
- [ ] #NNN — Push the hardcoded stub medication from iPhone to watch via `updateApplicationContext` and render its name (EPIC_02_ISSUE_05).

## Sequencing Notes

- **Blocks:** EPIC 03 (needs the model and a working sync channel). Most later epics also lean on this.
- **Depends on:** EPIC 01 (Xcode project, App Group, `WatchConnectivityCoordinator` stub).
- **Unblocks:** EPIC 03, EPIC 04, EPIC 05, EPIC 07.
- **Parallel-safe:** None during the sequence — children depend on each other.

## SPEC Reference

`plans/SPEC.md` §5 (Data Model, lines 114-263), §10 Phase 1 (lines 409-419), §11 (skill callouts for `Sendable` and `@Observable`).

## Labels

`epic`, `spec-decomposition`, `phase-1-data-model`, `tracer-code`.
