feat(ingredients): expand seed library to 116 entries

Expand `IngredientLibrarySeeder.seeds` from 6 → 116 across ten categorized
blocks. Threshold sourcing follows the policy from #155:

- OTC actives (analgesics, antihistamines, decongestants, cough/expectorant,
  GI) carry FDA-monograph / per-product-labeling thresholds.
- Vitamins and minerals carry NIH Office of Dietary Supplements Upper Limits
  where ODS publishes one; `nil` otherwise (no UL established).
- Prescription actives (mood, anticonvulsants, benzodiazepines, statins,
  cardiovascular, metabolic, endocrine, immunosuppressive) ship with
  `nil` thresholds. The user's prescriber owns those numbers.
- `isHighRisk: true` only on the narrow-TI Rx drugs the SPEC singles out:
  lithium, lamotrigine, valproate, carbamazepine, levothyroxine,
  methotrexate, warfarin, digoxin.

Existing seeded UUIDs are unchanged; `stableUUID(for:)` still derives from
the case-folded name. The `canonicalUUIDForAcetaminophenNeverChanges` test
remains the pin against the SHA-1 derivation drifting.

Test coverage:
- `libraryIsExpandedBeyondTheOriginalSix` — sanity floor at ≥100.
- `seedNamesAreUnique` + `seedStableUUIDsAreUnique` — collision check.
- `narrowTherapeuticIndexRxIsFlaggedHighRisk` — flag pin.
- `rxMaintenanceEntriesShipWithNilThresholds` — Rx contract.
- `otcAnalgesicsCarrySourcedThresholds` — OTC existing-value pin.
- `newOTCAntihistaminesCarrySourcedThresholds` — OTC expansion contract.
- `aliasesAreNonEmptyOnSeedsWithCommonSynonyms` — alias contract for
  autocomplete (#156).

Adjusted `suggestedIngredientReturnsNilWhenNothingMatches` in
HealthMedicationMapperTests — used a synthetic ingredient name since
Lithium is now in the seeded library.

Closes #155
Refs #5

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
