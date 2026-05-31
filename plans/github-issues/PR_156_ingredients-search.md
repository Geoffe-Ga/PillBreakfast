Closes #156
Refs #5

## Summary

After #155 the seeded library jumped 6 → 116 entries. The single alphabetical scroll became unworkable, and there was no entry point for adding a custom ingredient at all — the editor only opened from tapping an existing row. This wires `.searchable` autocomplete, a `+` toolbar create path, and a search-miss "Add 'foo'" row that pre-fills the editor.

- **New `Shared/Queries/IngredientFilter`** — case-insensitive substring match over `name` + each `alias`. `@MainActor` enum so the in-memory hot path can stay on the view's actor. Reused by #157 (medication-editor picker) so the two filter rules can't drift.
- **`.searchable` on `IngredientsListView`** filters in-memory; the library is bounded at ~120 seeds + user additions so a per-keystroke sort/pass is fine.
- **Search-miss row** — when a non-empty query yields no hits, the top of the list shows `Add "<query>" as new ingredient`, routing into create mode with the query pre-filled.
- **`+` toolbar item** opens create mode with an empty name field; you can still add custom ingredients without typing into search first.
- **`IngredientEditorView` create-mode init** — internal `Mode` enum (`.edit(Ingredient)` / `.create`) plus a second `init(creatingNamed:)`. Create mode adds a Name field at the top (autocapitalised, autocorrect off — chemical names break autocorrect), a Cancel toolbar item for the modal sheet flow, and inserts a new `Ingredient` on save instead of mutating an existing one. Edit-mode usage and behaviour are unchanged.
- **Delete index fix** — `.onDelete` now indexes into the filtered visible list rather than the full `ingredients` array, so deleting the third visible row while a filter is active deletes the right row.

## Test plan

- [x] **7 new `IngredientFilter` tests** in `PillBreakfastTests/Queries/IngredientFilterTests.swift`:
  - empty + whitespace-only query return all
  - name substring match, case-insensitive
  - alias substring match, case-insensitive
  - non-matching query returns empty
  - query whitespace is trimmed before matching
  - multi-match results preserve input order (matches `@Query`'s name-sort upstream)
- [x] Existing `IngredientsTests` deletion/high-risk tests still pass (no behavior change to those flows).
- [x] `pre-commit run --all-files` — clean.
- [x] Full `xcodebuild test` on iPhone 17 — `** TEST SUCCEEDED **`.
- [x] `xcodebuild build` on Apple Watch Series 11 — clean (`IngredientFilter` lives in `Shared/` and compiles into both targets).
- [ ] **Manual paired-sim check (deferred for reviewer)** — open Ingredients tab on iPhone 17; type "asp" → Aspirin appears; type "ASA" (the alias) → Aspirin still appears; type "zzz" → "Add 'zzz' as new ingredient" row appears; tap it → create-mode editor opens with "zzz" pre-filled in the name field; tap `+` from a cleared search → create-mode editor opens with an empty name field.
