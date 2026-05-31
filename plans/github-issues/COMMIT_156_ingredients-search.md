feat(ingredients): .searchable + add-on-miss on IngredientsListView

After #155 the library jumped from 6 to 116 entries; the single-list scroll
became unworkable and there was no path to add a custom ingredient at all.

- New `Shared/Queries/IngredientFilter` — case-insensitive substring
  match over `name` + each `alias`, used here and reused by #157.
- `IngredientsListView` adds `.searchable(text: $searchText, prompt: …)`,
  filters in-memory, and shows an "Add 'foo' as new ingredient" row at
  the top when the query has no hits.
- `+` toolbar item opens `IngredientEditorView` in create mode.
- Search-miss row routes into the same create mode with `initialName`
  pre-filled.
- `IngredientEditorView` gains an internal `Mode` enum and an
  `init(creatingNamed:)` alongside the existing `init(ingredient:)`.
  Create mode adds a Name field and a Cancel toolbar item; edit mode is
  unchanged. Save mutates-or-inserts based on mode.
- Delete now indexes into the filtered visible list so a partial filter
  doesn't delete the wrong row.

Tests:
- 7 `IngredientFilter` tests (empty/whitespace query, name + alias
  case-insensitive match, non-matching empty, whitespace-trim,
  input-order preservation).

Closes #156
Refs #5

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
