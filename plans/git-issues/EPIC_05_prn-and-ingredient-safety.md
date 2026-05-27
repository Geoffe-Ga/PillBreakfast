# EPIC 05 — Phase 4: PRN Flow + Ingredient-Aware Running Totals

## Epic Summary

The killer-feature epic. Both prescription PRN (Gabapentin) and OTC analgesics (Tylenol, Excedrin) work safely from the watch. Running totals aggregate **by ingredient across products**: 1500mg of standalone Tylenol plus 4 tablets of Excedrin Extra Strength (1000mg more acetaminophen) trips the acetaminophen ceiling warning even though the product names are different. Implements SPEC §10 Phase 4 (lines 442-456) and the ingredient-aware safety logic from §5.3.

This is the epic where the §5.1 "ingredient layer" pays off. Without it, the app would happily show "Tylenol: 1500mg today" while the user blows past the 4000mg acetaminophen ceiling that actually matters.

## Scope

**In scope:**

- **iPhone PRN configuration UI:** finish the half-stubbed PRN form from EPIC 03 — `prnAvailableQuantities` editor (e.g. `[1, 2, 3]` for 100mg gabapentin capsules), multi-component product entry for combo OTCs (Excedrin Extra Strength = 250mg acetaminophen + 250mg aspirin + 65mg caffeine per tablet).
- **iPhone Ingredients screen** (SPEC §6.1, accessed from settings or the Regimen edit view): manage the ingredient library — edit `dailyCeilingMg`, `minIntervalMinutes`, `isHighRisk`. Disclaimer: "you are responsible for confirming with your prescriber."
- **Watch PRN section (§7.3):** list of PRN products, each row showing the most-relevant ingredient running total per the SPEC's rules:
  - Single-ingredient meds: `"Gabapentin · 600 mg today · last 11:42 AM"`
  - Single-ingredient OTC: `"Tylenol · 1500 mg acetaminophen today · last 11:42 AM"`
  - Combo product: `"Excedrin · last 11:42 AM · acetaminophen 38% of daily limit"` (highest-utilization ingredient).
- **Quantity picker:** uses `prnAvailableQuantities` from the product. Single-tap for non-high-risk, press-and-hold for high-risk (reuses the EPIC 04 gesture).
- **Query helpers in `Shared/`:** `totalToday(ingredient:)` and `lastDoseTime(ingredient:)` operating on the denormalized `LoggedIngredientAmount` snapshots. Property-based tests with synthetic dose-event fixtures.
- **`violationsIfTaken(_:quantity:at:)` safety check** per SPEC §5.3, returning a typed `[Violation]` enum with `.ceiling(ingredient, current:, proposed:, ceiling:)` and `.tooSoon(ingredient, lastTakenAt:, minInterval:)` cases.
- **Soft warning interstitial** on the watch that names the **ingredient** (not just the product) that's at risk, with current total and proposed total. User can override with the same gesture rules as the underlying med.
- **Three killer test cases** as automated test scenarios using synthetic fixtures:
  1. Gabapentin self-pacing — 600mg taken, attempt >1200mg cumulative, warning fires, override works.
  2. Tylenol self-pacing — 1000mg taken, attempt another 1000mg within 4 hours, min-interval warning fires.
  3. **Cross-product safety (the killer test)** — 1500mg standalone Tylenol logged, then attempt 4 tablets of Excedrin Extra Strength (1000mg more acetaminophen). Warning fires on acetaminophen total > 4000mg daily ceiling. Different product names, shared ingredient.

**Out of scope:**

- Snooze flow (EPIC 06).
- HealthKit import of combo products (EPIC 07; combo ingredient mapping is messy and Health does not expose composition reliably — the EPIC 07 import flow makes the user confirm components).
- Pill imagery (SPEC §12 future work).

## Critical Architecture (carry into every child issue)

- **Running totals must aggregate by ingredient, not by product.** The whole point of the §5.1 ingredient layer. `totalToday(ingredient:)` sums `LoggedIngredientAmount.totalMg` across every `DoseEvent` from today that contains the ingredient.
- **`DoseEvent.ingredientAmounts` is filled at log time**, denormalized from the product's current `components`. Do not query through the live `Medication -> components -> ingredient` relationship on read — the denormalization is what makes editing a product's components later not retroactively rewrite history (SPEC §5.3).
- **"Last dose" timestamp on the PRN row reflects the product**, but safety checks aggregate by ingredient. SPEC §7.3 spells this out: "take 2 Tylenol at 11:42 AM, then try to take 2 Excedrin at 1:42 PM, and the warning will fire on the shared acetaminophen interval even though it's a different product."
- **Warnings are soft.** The user can always override (with the same press-and-hold gesture if the med is high-risk). This is a tool, not a guardrail that locks them out.
- **Seeded ingredient ceilings are suggestions, not medical advice.** Ship with the disclaimer prominent.

## Success Criteria

The epic is done when:

- [ ] All three SPEC §10 Phase 4 gate test cases pass as automated tests.
- [ ] The watch PRN section shows ingredient-level totals on all three row variants (single-ingredient prescription, single-ingredient OTC, combo).
- [ ] Logging a PRN dose writes a `DoseEvent` with a complete `ingredientAmounts` snapshot reflecting that product's components at the moment of logging.
- [ ] Editing a product's components later does not change historical `DoseEvent.ingredientAmounts` values.
- [ ] All child issues are closed.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #NNN — Skeleton: Watch PRN section list view + iPhone PRN form, both wired to SwiftData but with stub ingredient totals (EPIC_05_ISSUE_01).
- [ ] #NNN — Implement `totalToday(ingredient:)` and `lastDoseTime(ingredient:)` query helpers over `LoggedIngredientAmount` snapshots (EPIC_05_ISSUE_02).
- [ ] #NNN — Implement `violationsIfTaken(_:quantity:at:)` returning typed `[Violation]` per SPEC §5.3 with the three killer test cases as automated tests (EPIC_05_ISSUE_03).
- [ ] #NNN — Watch quantity picker + ingredient-aware row rendering (single-ingredient prescription, single-ingredient OTC, combo product variants) (EPIC_05_ISSUE_04).
- [ ] #NNN — Soft warning interstitial that names the ingredient and shows current/proposed total; honors high-risk press-and-hold rules on override (EPIC_05_ISSUE_05).
- [ ] #NNN — iPhone Ingredients screen for managing the ingredient library with disclaimer (EPIC_05_ISSUE_06).

## Sequencing Notes

- **Blocks:** EPIC 09 (PDF export wants ingredient-level totals in the history).
- **Depends on:** EPIC 02 (data model), EPIC 03 (logging machinery), EPIC 04 (press-and-hold for high-risk PRN overrides).
- **Unblocks:** EPIC 09.
- **Parallel-safe:** EPIC 06 (snooze) can run alongside EPIC 05's iPhone-side work.

## SPEC Reference

`plans/SPEC.md` §2.3 (PRN journey), §5.1 (ingredient layer rationale), §5.2-5.3 (schema and safety pseudocode, lines 128-263), §6.1 (iPhone PRN config + Ingredients screen), §7.3 (watch PRN section, lines 322-331), §10 Phase 4 (lines 442-456) with the three gate test cases, §11 (Phase 4 skill callout: many-to-many SwiftData modeling).

## Labels

`epic`, `spec-decomposition`, `phase-4-prn-safety`, `tracer-code`.
