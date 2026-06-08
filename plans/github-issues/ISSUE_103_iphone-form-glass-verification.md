## Role

You are a senior SwiftUI / design-system engineer hardening the Phase 3 Liquid Glass first pass on the iPhone Regimen form. PR #102 applied glass to `MedicationFormView` and `RegimenListView`; the reviewer flagged two visual risks that can only be confirmed by eyeballing a paired iPhone 17 simulator: (1) double-glass when the form is presented inside a `.sheet`, and (2) validation-error text dipping below a legible floor under glass. You fix both root causes, add the regression guards, then run the manual verification protocol and attach screenshot evidence.

## Goal

The Add medication sheet renders exactly **one** glass layer (platform sheet chrome only) and looks visually consistent with the Edit medication push (which keeps its single view-level `.glassBackground()`). Validation-error rows render at a pinned **`.footnote` floor (13 pt default)** via a new self-documenting `errorText` Typography helper — never `captionFont` (12 pt), never the high-risk amber accent. A unit test pins the new token, a UI test proves the error rows render with non-zero height, and the manual Dynamic-Type + light/dark protocol is completed with screenshots attached to the PR.

## Context

- **Parent epic:** #103 (this issue stays a single enriched issue per the spec's Decomposition Hints — "small enough for a single issue/PR"; the glass fix and the error-text fix share the same file, the same PR, and one verification protocol). Phase epic: #4.
- **Predecessors:** PR #102 (introduced the glass treatment on `MedicationFormView` / `RegimenListView`). No code predecessor blocks this; it operates on already-landed views.
- **Spec sections:**
  - `plans/2026-06-07_SPEC_ISSUE-103_iphone-form-glass-verification.md` §5.1 (sheet glass-stacking RCA + `appliesGlassBackground` fix), §5.2 (error-text token + Dynamic Type matrix), §5.3 / §8.3 (manual verification protocol), §8 (regression guards), §11 (acceptance criteria).
  - SPEC §6.1 (iPhone Regimen tab), §9 (Liquid Glass language: monochrome baseline, depth via refraction not color), §10 Phase 3 gate ("looks like a watchOS 26 native app, not a port of iOS chrome").
  - CLAUDE.md — "Color is reserved for high-risk meds. Baseline UI is monochromatic glass."
- **Files involved:**
  - `PillBreakfast/RegimenTab/MedicationFormView.swift` — currently applies `.glassBackground()` unconditionally (line ~112) and renders errors via `LiquidGlassTheme.Typography.footnote(error)` (line ~87). Add an `appliesGlassBackground: Bool = true` parameter; gate the glass modifier on it; swap the error builder to the new `errorText` helper.
  - `PillBreakfast/RegimenTab/AddMedicationView.swift` — sheet host (`.presentationDetents([.large])`, `.interactiveDismissDisabled(true)`). Pass `appliesGlassBackground: false` so only the platform sheet chrome supplies glass.
  - `PillBreakfast/RegimenTab/EditMedicationView.swift` — push host; **unchanged** (keeps the default `true`; view-level glass is its sole glass source).
  - `Shared/DesignSystem/Typography.swift` — add `errorText(_:)` helper (maps to `footnoteFont`). The file has `footnote(_:)` today; `errorText`/`errorTextFont` do **not** exist yet.
  - `Shared/DesignSystem/View+GlassBackground.swift` — home for the new `View.if(_:transform:)` convenience (it does **not** exist in the repo yet; confirmed by grep) OR keep the conditional inline in `MedicationFormView` without a helper.
  - `Shared/DesignSystem/LiquidGlassTheme.swift` — token source (`footnoteFont`, `captionFont`, `highRiskAccent`); read-only reference.
  - `PillBreakfast/RegimenTab/NewIngredientView` (private in `MedicationFormView.swift`) — nested sheet; **do not** add `.glassBackground()`; verify legibility only.
  - `PillBreakfastTests/DesignSystem/LiquidGlassThemeTests.swift` — add the `errorText` token test.
  - `PillBreakfastUITests/` — add the validation-error visibility UI test.
- **Prior decisions (locked):**
  - Inside a `.sheet`, the **platform sheet chrome is the glass source** — rely on `.scrollContentBackground(.hidden)` alone and suppress the view-level `.glassBackground()`. Inside a `NavigationLink` push, `.glassBackground()` **is** the glass source and must stay.
  - Error text is `.red` (a validation-failure semantic, part of the iOS affordance vocabulary). It **must never** use `LiquidGlassTheme.Colors.highRiskAccent` — amber means "high-risk medication," not "form error." Error semantics ≠ high-risk semantics.
  - Error-text floor is `.footnote` (13 pt default). `captionFont` (12 pt → 11 pt at xSmall) is too small under glass.
  - Baseline UI is monochrome glass; do not add color to any non-error, non-high-risk surface.
  - iPhone is setup/review only — no logging UI, no "take pills now" prompts. This is iPhone-only; the watch surface is untouched.
  - `NewIngredientView` keeps no `.glassBackground()` (platform handles nested-sheet glass). If its inner `Form` is illegible, the **only** allowed change is `.scrollContentBackground(.hidden)` — never a second `.glassBackground()`.

## Output Format

A single PR containing:

- [ ] `MedicationFormView` gains `var appliesGlassBackground: Bool = true`, documented with a comment pointing at issue #103 (so a future reader knows to revisit if iOS 26 sheet chrome changes). `.glassBackground()` is applied only when the flag is `true`; `.scrollContentBackground(.hidden)` stays unconditional.
- [ ] `AddMedicationView` passes `appliesGlassBackground: false`. `EditMedicationView` is unchanged.
- [ ] If a `View.if(_:transform:)` helper is used for the conditional, it is added once to `Shared/DesignSystem/` (it is not in the repo). Inlining the conditional without a helper is also acceptable — pick one and keep it clean.
- [ ] `LiquidGlassTheme.Typography.errorText(_:)` (or `Typography.errorText(_:)` matching the file's existing builder style) added, mapping to `footnoteFont`, with a doc comment stating the legible-floor policy and that color is set by the call site (`.red`, never `highRiskAccent`).
- [ ] `MedicationFormView`'s error section calls `errorText(error)` instead of `footnote(error)`; `.foregroundStyle(.red)` retained; no `lineLimit` added.
- [ ] Unit test in `LiquidGlassThemeTests` pinning `errorText` to `footnoteFont`.
- [ ] UI test in `PillBreakfastUITests` that opens the Add medication sheet, triggers validation, and asserts the error text element exists with non-zero frame height at default Dynamic Type.
- [ ] Manual verification protocol completed (see Done-Done): Add sheet single-layer, Add-vs-Edit consistency, nested New Ingredient legibility, error text at xSmall / default Large / Accessibility Large in light + dark. Screenshots stored under `plans/screenshots/issue-103/` and referenced in the PR description.

## Examples

The glass-context parameter (spec §5.1.2):

```swift
struct MedicationFormView: View {
    // ... existing properties ...

    /// When `true` (default, push-context), the form applies `.glassBackground()`
    /// as its own glass surface. Pass `false` when embedded inside a `.sheet` that
    /// already provides glass chrome at the presentation layer (AddMedicationView).
    /// See issue #103 — revisit if iOS 26 sheet chrome stops supplying glass.
    var appliesGlassBackground: Bool = true

    var body: some View {
        Form { /* ... existing sections ... */ }
            .scrollContentBackground(.hidden)
            .if(appliesGlassBackground) { $0.glassBackground() }
            // ... existing modifiers ...
    }
}
```

The error-text helper (spec §5.2.1, Option A — preferred):

```swift
/// Validation-error text on forms. Minimum `.footnote` (13 pt default) so the
/// user-must-act prompt is legible at default and smaller Dynamic Type settings.
/// Color is set by the call site (`.red` for validation, never `highRiskAccent`).
static func errorText(_ text: String) -> Text {
    Text(text).font(footnoteFont)
}
```

The token unit test (spec §8.1):

```swift
@Test func errorTextBuilderAppliesFootnoteFont() {
    let text = "Name required."
    #expect(
        LiquidGlassTheme.Typography.errorText(text)
            == Text(text).font(LiquidGlassTheme.Typography.footnoteFont)
    )
}
```

## Constraints

**Scope fence:** Two fixes only — suppress double-glass in the sheet context, and pin the error-text floor via the `errorText` token — plus their regression guards and the manual verification. **No** redesign of the Regimen tab or the medication form layout. **No** new validation rules or error messages. **No** glass change to `EditMedicationView`, `IngredientPickerView`, or `IngredientsListView` (push destinations — correct today). **No** `.glassBackground()` added to `NewIngredientView`. **No** snapshot-testing library (deferred to Phase 9). **No** leading error glyph (deferred to the Phase 9 accessibility pass — note only). **No** color on any non-error, non-high-risk surface. iPhone-only — the watch logging surface is out of scope.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After the change the app still builds and runs on a paired iPhone 17 + Apple Watch Series 11 simulator. The Add medication flow is unchanged behaviorally — open the sheet, fill the form, save a med — only the glass depth and the error-text size differ. The Edit medication push looks identical to before. Both schemes (`PillBreakfast` iOS and `PillBreakfast Watch App Watch App`) keep building.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] Verification protocol from the spec completed on the iPhone 17 simulator across the specified Dynamic Type sizes + light/dark; screenshot evidence attached to the PR.
- [ ] PR opened with `Closes #<this issue>` and `Refs #103` (and cross-ref phase epic #4).
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `design-system`, `phase-3-high-risk`, `polish`, `core`, `a11y`, `tests`
