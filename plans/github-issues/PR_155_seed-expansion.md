Closes #155
Refs #5

## Summary

Expand `IngredientLibrarySeeder.seeds` from 6 → **116** across ten categorized blocks. Threshold sourcing follows the policy from the issue:

- **OTC actives** — analgesics, antihistamines, decongestants, cough/expectorant, GI — carry FDA-monograph / per-product-labeling thresholds (cited inline per category block).
- **Vitamins and minerals** carry NIH ODS Upper Limits where ODS publishes one; `nil` otherwise (B1, B2, B5, B7, B12, K1, K2, potassium, chromium — ODS reports "no UL established").
- **Prescription actives** ship name + aliases + `isHighRisk` only, with `nil` thresholds. The user's prescriber owns those numbers; PillBreakfast doesn't invent ceilings for narrow-TI Rx drugs.
- **`isHighRisk: true`** only on the narrow-TI Rx drugs the SPEC singles out as press-and-hold-worthy: lithium carbonate, lamotrigine, valproate, carbamazepine, levothyroxine, methotrexate, warfarin, digoxin.

The expanded `seeds` is composed by concatenating ten private per-category arrays (`otcAnalgesics + otcAntihistamines + … + rxMaintenance`) so each block can document its sourcing rule independently and a future addition lands in the right place visually.

Existing seeded UUIDs are unchanged — `stableUUID(for:)` still derives from the case-folded name and the `canonicalUUIDForAcetaminophenNeverChanges` test pins the SHA-1 derivation against drift.

### Coverage by category

| Block | Count | Threshold rule |
|---|---|---|
| OTC analgesics | 5 | FDA 21 CFR Part 343 |
| OTC antihistamines | 10 | FDA 21 CFR Part 341 + product labeling |
| OTC decongestants | 3 | FDA 21 CFR Part 341 |
| OTC cough/expectorant | 3 | FDA 21 CFR Part 341 |
| OTC GI | 14 | FDA OTC monographs + per-NDA OTC labels |
| Vitamins | 17 | NIH ODS ULs where defined |
| Minerals | 13 | NIH ODS ULs where defined |
| Supplements | 13 | Name-only (no ODS UL) |
| Stimulants | 3 | FDA cite for caffeine; nil otherwise |
| Rx maintenance | 35 | Name + alias + isHighRisk only |
| **Total** | **116** | |

## Test plan

- [x] **8 new tests + 7 existing tests** all pass — see `IngredientLibrarySeederTests`.
  - `libraryIsExpandedBeyondTheOriginalSix` — sanity floor at ≥100.
  - `seedNamesAreUnique` and `seedStableUUIDsAreUnique` — guard against case-folded name collisions and SHA-1 derivation collisions.
  - `narrowTherapeuticIndexRxIsFlaggedHighRisk` — pin `isHighRisk: true` on the eight named narrow-TI Rx.
  - `rxMaintenanceEntriesShipWithNilThresholds` — pin the Rx contract (no invented ceilings).
  - `otcAnalgesicsCarrySourcedThresholds` — pin the original 4 OTC analgesic ceiling/interval values so a future edit can't silently change them.
  - `newOTCAntihistaminesCarrySourcedThresholds` — pin the new OTC antihistamine thresholds.
  - `aliasesAreNonEmptyOnSeedsWithCommonSynonyms` — pin alias contracts for autocomplete (#156).
- [x] Adjusted `suggestedIngredientReturnsNilWhenNothingMatches` in `HealthMedicationMapperTests` to use a synthetic ingredient name (the test previously relied on "Lithium" not being in the library, which is no longer true).
- [x] `pre-commit run --all-files` — clean.
- [x] Full `xcodebuild test` on iPhone 17 — `** TEST SUCCEEDED **`.
- [x] `xcodebuild build` on Apple Watch Series 11 — clean (Shared/-resident change, both targets compile).
