# SPEC: Issue #103 — iPhone Form Glass Verification
## Sheet Stacking + Error-Text Size under Liquid Glass

---

**Issue:** #103
**Phase:** 3 (High-Risk Confirmation + Liquid Glass First Pass)
**Labels:** `spec-decomposition`, `needs-spec`, `design-system`, `phase-3-high-risk`
**Status:** Draft
**Date:** 2026-06-07
**Author:** Architecture Design Agent (Level 2)
**Related issues:** #4 (Liquid Glass design system), #102 (PR that introduced the glass treatment on
`MedicationFormView` and `RegimenListView`), Phase 3 gate in SPEC §10

---

## 1. Summary

PR #102 applied `.scrollContentBackground(.hidden)` and `.glassBackground()` to `MedicationFormView`
and `RegimenListView` as part of the Phase 3 Liquid Glass first pass. Two visual risks were
surfaced in the PR review that could not be verified in the headless CI/agent flow and require
eyeballing on a paired iPhone 17 simulator:

1. **Sheet glass-stacking.** `MedicationFormView` is presented as a `.sheet` from
   `AddMedicationView`. On iOS 26, a `.sheet` may already apply a glass material at the
   presentation layer. If it does, the form's own `.glassBackground()` stacks a second glass layer,
   producing visible over-blurring, unintended double-refraction, and a heavier scrim than the
   system intends. `EditMedicationView` pushes the same form via `NavigationLink` (a non-sheet
   context), so the two presentations may behave differently and must look consistent with each
   other.

2. **Validation-error text size.** PR #102 changed the error-text font from `.footnote` to
   `LiquidGlassTheme.Typography.captionFont` (`.system(.caption, design: .rounded)` — 12 pt at
   default Dynamic Type). The change narrows the floor size. The concern is whether validation
   messages remain legible at default and larger Dynamic Type categories, and whether they remain
   clearly distinguishable from normal secondary text without borrowing the high-risk amber accent.

This spec defines the exact verification protocol, the correct expected outcomes, the code changes
likely needed, and the regression guards to prevent both issues from quietly regretting.

---

## 2. Problem Statement / Motivation

### 2.1 Sheet Glass-Stacking

`View+GlassBackground.swift` implements `.glassBackground()` as:

```swift
func glassBackground() -> some View {
    background {
        Color.clear
            .glassEffect()
            .ignoresSafeArea()
    }
}
```

This attaches a `glassEffect()` fill to whatever view it is applied to. When `MedicationFormView`
carries this modifier and is presented inside a `.sheet`, and if iOS 26 sheets already supply a
glass material (which the platform does — `.sheet` in iOS 26 uses a translucent glass-tinted chrome
by default), the result is two glass layers. Double-glass manifests as:

- An over-blurred background that loses depth information and reads as grey mud rather than
  translucent glass.
- A heavier perceived shadow under the sheet handle — the system-level scrim stacks on top of the
  refraction added by the view-level modifier.
- A visual inconsistency between the "Add medication" path (sheet-presented `MedicationFormView`)
  and the "Edit medication" path (`EditMedicationView` pushing `MedicationFormView` via
  `NavigationLink` inside `RegimenTabHostView`'s `NavigationStack`). In the push context, there is
  no system-supplied sheet glass, so `.glassBackground()` is the sole source of the translucent
  treatment and should be preserved.

The correct leaf-level strategy (noted in the PR review) is: inside a `.sheet`, rely on
`.scrollContentBackground(.hidden)` alone and let the system-provided sheet chrome supply the glass
surface. Inside a `NavigationLink` push, `.glassBackground()` is the glass source and must stay.

A nested sheet is also possible in this flow: `MedicationFormView` itself presents
`NewIngredientView` in a `.sheet` (the `.sheet(isPresented: $showingNewIngredient)` modifier on the
`Form`). `NewIngredientView` wraps a plain `Form` inside a `NavigationStack` and does not apply
`.glassBackground()` — but it inherits the context of already being inside a sheet-inside-a-sheet,
so iOS 26's stacked sheet behavior (detent, scrim depth) applies. This second-level stacking must
also be verified.

### 2.2 Validation-Error Text Size

In `MedicationFormView`, the validation-error section renders as:

```swift
if hasInteracted, !formState.validationErrors.isEmpty {
    Section {
        ForEach(formState.validationErrors, id: \.self) { error in
            LiquidGlassTheme.Typography.footnote(error)
                .foregroundStyle(.red)
        }
    }
}
```

The `footnote` builder applies `LiquidGlassTheme.Typography.footnoteFont`, which is
`.system(.footnote, design: .rounded)` (13 pt at default Dynamic Type). However, the issue body
states that PR #102 changed the font to `captionFont` (12 pt). Reconciling this: either the
issue body is slightly ahead of what landed, or the current code is the corrected state after a
subsequent fixup. In either reading, the token in use must be verified against the full Dynamic
Type range.

At the maximum system Dynamic Type size (Accessibility Extra Extra Extra Large, denoted
`xxxAccessibilityLarge`), `.caption` scales to approximately 23 pt while `.footnote` scales to
approximately 25 pt — the gap is small, but the floor matters more: at the minimum size
(`xSmall`), `.caption` is 11 pt and `.footnote` is 12 pt. Both are borderline; under a glass
background with imperfect contrast, 11–12 pt red text against a translucent surface can fall below
WCAG AA readability (minimum 4.5:1 contrast ratio for normal text).

The second concern is semantic color discipline. The CLAUDE.md and SPEC §9 reserve the amber
accent (`LiquidGlassTheme.Colors.highRiskAccent`) strictly for high-risk medication confirmations on
the watch logging surface. Error text on the iPhone setup form is a different semantic category
(validation failure, not medication risk), so `.red` is the correct signal — but the inline comment
in `MedicationFormView` already acknowledges this distinction. The concern is not that `.red` is
wrong, but that `.red` on a glass background may not meet contrast at all Dynamic Type and
appearance combinations.

---

## 3. Goals and Non-Goals

### Goals

- Verify that the Add medication sheet presents exactly one glass layer and adjust if it stacks.
- Verify that the Edit medication push (NavigationLink) renders consistently with the sheet
  presentation.
- Verify that the nested New Ingredient sheet (presented from within the Add medication sheet)
  layers correctly and remains legible.
- Verify that validation-error text is legibly sized at all tested Dynamic Type categories.
- Verify that `.red` error text is sufficiently distinct from secondary `.secondary` text and from
  the glass background at both light and dark appearances.
- Define a token (`errorText`) or policy (`footnoteFont` minimum for error text) to prevent future
  regressions.
- Define UI test and snapshot guards to catch future regressions in CI.

### Non-Goals

- Redesigning the overall Regimen tab or medication form layout.
- Adding new validation rules or error messages.
- Changing the Add medication flow in any way other than the glass-layer adjustment.
- Modifying the watch logging surface (this spec is iPhone-only).
- Adding color to any non-error, non-high-risk surface (color discipline is locked).
- Changing `IngredientPickerView` glass treatment (it is a push destination, not a sheet;
  the same glass behavior as the edit path applies and is correct).

---

## 4. Background and Current State

### 4.1 Presentation Hierarchy in the Regimen Tab

```
RegimenTabHostView
  NavigationStack
    RegimenListView              ← .scrollContentBackground(.hidden) + .glassBackground()
      .sheet → AddMedicationView
        NavigationStack
          MedicationFormView     ← .scrollContentBackground(.hidden) + .glassBackground()
            .sheet → NewIngredientView
              NavigationStack
                Form             ← no explicit glass modifier (inherits sheet chrome)
      NavigationLink → EditMedicationView
        MedicationFormView       ← .scrollContentBackground(.hidden) + .glassBackground()
          NavigationLink → IngredientPickerView
            List                 ← no explicit glass modifier
          NavigationLink → IngredientsListView
            ...
```

Key observations:

- `AddMedicationView` is a sheet (`.sheet(isPresented: $showingAdd)` in `RegimenListView`). Its
  content root is a `NavigationStack` wrapping `MedicationFormView`. The `NavigationStack` itself
  does not add glass. `MedicationFormView` carries `.glassBackground()`. The `AddMedicationView`
  also carries `.presentationDetents([.large])` and `.interactiveDismissDisabled(true)`.

- `EditMedicationView` is a NavigationLink destination (pushed inside the `RegimenTabHostView`
  `NavigationStack`). It renders `MedicationFormView` with no intermediate sheet chrome. Here,
  `.glassBackground()` is the only glass source and must stay.

- `NewIngredientView` (private to `MedicationFormView.swift`) is a `.sheet` presented from within
  `MedicationFormView`. It wraps a plain `Form` inside a `NavigationStack` and has no explicit
  glass modifier. Because it is a second-level sheet (sheet inside sheet), iOS 26 natively stacks
  a narrower detent above the parent sheet and applies a glass tint with offset perspective.

### 4.2 Design System Tokens in Use

From `Shared/DesignSystem/LiquidGlassTheme.swift`:

- `captionFont`: `.system(.caption, design: .rounded)` — 12 pt default, scales to ~23 pt at
  `xxxAccessibilityLarge`.
- `footnoteFont`: `.system(.footnote, design: .rounded)` — 13 pt default, scales to ~25 pt at
  `xxxAccessibilityLarge`.
- `highRiskAccent`: fixed sRGB `Color(red: 0.96, green: 0.66, blue: 0.27)` — NOT for error text.
- `secondaryText`: `.secondary` (adaptive; tracks system appearance).

The design system has no dedicated `errorTextFont` token. The current implementation uses
`LiquidGlassTheme.Typography.footnote(error)` (confirmed from the live `MedicationFormView`
source), which applies `footnoteFont` (13 pt default). The issue body's reference to `captionFont`
either anticipates a regression or describes a briefly-landed state; the code as read uses
`footnoteFont`. Either way, the floor must be pinned explicitly.

### 4.3 `.glassBackground()` Implementation

The modifier is a `background` with a `Color.clear.glassEffect().ignoresSafeArea()`. On iOS 26,
`.glassEffect()` produces a translucent, refractive material that blurs the content behind the
modified view. When applied to a `Form` inside a `.sheet`, and the sheet's presentation chrome
already applies its own glass material to the entire sheet surface, the two layers combine.

### 4.4 Existing Test Coverage

- `PillBreakfastTests/DesignSystem/LiquidGlassThemeTests.swift` — pins token values (spacing,
  color, typography builders, elevation, corner radius, motion). Does not cover glass-layer
  application behavior, which requires simulator rendering.
- `PillBreakfastTests/RegimenTab/MedicationFormStateTests.swift` — tests validation-error string
  generation only; does not test how those strings are rendered.
- `PillBreakfastUITests/MemoryReproUITests.swift` — drives the Add medication form for memory
  profiling; does not assert visual properties.
- No snapshot tests exist. No UI tests assert element accessibility sizes.

---

## 5. Detailed Design and Verification Plan

### 5.1 Risk Area 1: Sheet Glass-Stacking

#### 5.1.1 Root Cause Analysis

iOS 26 `.sheet` presentations apply a system-managed glass material to the sheet's container
view at the presentation layer (the sheet chrome itself). This is the platform default. Any
`glassEffect()` applied to content inside the sheet therefore stacks a second blur/refraction pass
on top of the platform-managed one.

`AddMedicationView` presents `MedicationFormView` inside a `NavigationStack`. The `MedicationFormView` body calls `.glassBackground()` on its `Form`. The `Form`'s background is already within the sheet's glass chrome. Result: two glass layers.

`EditMedicationView` is a push destination; no sheet chrome is present. `MedicationFormView`'s
`.glassBackground()` is the only glass source. Result: correct single layer.

The correct fix is conditional glass application: `MedicationFormView` should apply
`.glassBackground()` only when it is not already inside a sheet-provided glass container.

#### 5.1.2 Fix Strategy

The cleanest approach is to make `MedicationFormView` accept a parameter controlling whether it
applies `.glassBackground()`, defaulting to the push-context behavior (apply it), and letting
`AddMedicationView` override to `false`:

```swift
struct MedicationFormView: View {
    // ... existing properties ...

    /// When `true` (the default, push-context behavior), the form applies
    /// `.glassBackground()` as its own glass surface. Pass `false` when the
    /// form is embedded inside a `.sheet` that already provides glass chrome
    /// at the presentation layer (e.g. AddMedicationView).
    var appliesGlassBackground: Bool = true

    var body: some View {
        Form { /* ... existing sections ... */ }
            .scrollContentBackground(.hidden)
            .if(appliesGlassBackground) { $0.glassBackground() }
            // ... existing modifiers ...
    }
}
```

`AddMedicationView` passes `false`:

```swift
MedicationFormView(formState: formState, appliesGlassBackground: false) { ... }
```

`EditMedicationView` retains the default (`true`) and does not change.

An alternative approach is to use SwiftUI's environment to propagate a "we are inside a sheet"
flag, but a direct parameter is simpler, more explicit, and easier to unit-reason about. The
`View+if` convenience modifier already exists elsewhere in many codebases; if it is not present
in `PillBreakfast`, add it to `Shared/DesignSystem/` as a small extension:

```swift
extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition { transform(self) }
        else { self }
    }
}
```

#### 5.1.3 NewIngredientView Nested Sheet

`NewIngredientView` does not call `.glassBackground()`. On iOS 26, a sheet presented from within
a sheet (depth 2) inherits the platform's stacked-sheet treatment — a narrower detent with an
additional perspective offset. The platform chrome handles the glass surface here, so no code
change is needed. Verification must confirm that the content inside `NewIngredientView` (a plain
`Form`) remains legible with the double-sheet glass depth. If legibility is compromised, apply
`.scrollContentBackground(.hidden)` to the inner `Form` to allow the platform glass to read
through — but do not add another `.glassBackground()`.

#### 5.1.4 Stacking Scenarios to Verify

| Scenario | Presentation type | Expected glass layers | Risk |
|---|---|---|---|
| Add medication (large detent sheet) | `.sheet` over RegimenListView | 1 (platform chrome only after fix) | HIGH — current code stacks 2 |
| Edit medication (NavigationLink push) | NavigationLink destination | 1 (view-level `.glassBackground()`) | LOW — no sheet chrome; correct today |
| New Ingredient (sheet inside sheet) | `.sheet` inside AddMedicationView `.sheet` | 1 per layer (platform handles both) | MEDIUM — must verify legibility |
| IngredientPickerView (push inside sheet) | NavigationLink inside AddMedicationView | Sheet chrome from parent + no extra glass | LOW — no modifier applied here |
| Ingredient editor from RegimenListView | NavigationLink inside NavigationStack | 1 (view-level `.glassBackground()`) | LOW — correct today |

### 5.2 Risk Area 2: Error-Text Size

#### 5.2.1 Token Selection

Validation-error text must be rendered at a minimum of `LiquidGlassTheme.Typography.footnoteFont`
(`.system(.footnote, design: .rounded)`, 13 pt at default Dynamic Type). Using `captionFont`
(12 pt default) is too small for text that requires user attention to correct a form submission
error. The distinction: `.footnote` is already described in the design system as "legible secondary
copy" for row subtitles and timestamps; `.caption` is "smallest supporting text" for chip labels
and dense metadata. Error text is an actionable prompt — it sits above `.caption` semantically.

The design system does not yet have a dedicated `errorTextFont` token. Two options:

**Option A (preferred):** Continue using `footnoteFont` and add a comment documenting the
minimum-size policy. Add a new `errorText` helper to `LiquidGlassTheme.Typography` that makes
the policy explicit:

```swift
/// Validation-error text on forms. Minimum `.footnote` (13 pt default) so the
/// user-must-act prompt is legible at default and smaller Dynamic Type settings.
/// Color is set by the call site (`.red` for validation, never `highRiskAccent`).
public static func errorText(_ text: String) -> Text {
    Text(text).font(footnoteFont)
}
```

**Option B:** Add a distinct `errorTextFont` token that maps to `.footnote` today but can be
independently adjusted if the design needs to differentiate further. This is architecturally
cleaner but adds token proliferation for a single call site.

Option A is recommended: it names the semantic intent without adding a second font at the same
point size, and the helper makes call sites self-documenting.

#### 5.2.2 Color Discipline

`.red` on a glass background must achieve WCAG AA contrast (4.5:1 for text below 18 pt, 3:1 for
text 18 pt and above or 14 pt bold). At the `.footnote` floor of 13 pt (non-bold, rounded design),
the 4.5:1 threshold applies.

In light mode, system red (`Color.red` → `UIColor.systemRed` → approximately `#FF3B30`) against a
translucent glass background reading through a white-dominant content layer typically achieves
4.5:1 or better. In dark mode, system red lightens slightly to remain visible on dark surfaces.

The risk is the glass background rather than a solid white/dark surface: the contrast ratio is
not fixed and depends on what content appears behind the sheet. On the iPhone 17 simulator the
default backdrop is the home screen or blurred app content.

Recommended verification: set the simulator wallpaper to a midtone image and verify red text
remains distinguishable. Do not apply any additional background treatment to the error section —
the system `Section` chrome (part of the glass-styled `Form`) provides sufficient containment.

#### 5.2.3 Dynamic Type Behavior Matrix

The following sizes must be verified on the iPhone 17 simulator using Settings > Accessibility >
Display & Text Size > Larger Text:

| Dynamic Type category | `.footnote` size (pt) | `.caption` size (pt) | Minimum legibility (pass/fail) |
|---|---|---|---|
| xSmall | 12 | 11 | `.footnote` pass; `.caption` borderline |
| Small | 12 | 11 | `.footnote` pass; `.caption` borderline |
| Medium (default) | 13 | 12 | Both acceptable; `.footnote` preferred |
| Large (iOS default) | 13 | 12 | Both acceptable |
| xLarge | 15 | 14 | Both pass |
| xxLarge | 17 | 16 | Both pass |
| xxxLarge | 19 | 18 | Both pass |
| Accessibility Medium | 23 | 21 | Both pass |
| Accessibility Large | 28 | 26 | Both pass |
| Accessibility xLarge | 33 | 31 | Both pass |
| Accessibility xxLarge | 40 | 38 | Both pass |
| Accessibility xxxLarge | 47 | 44 | Both pass |

At xSmall and Small, `captionFont` at 11 pt against glass is the failure risk. `footnoteFont` at
12 pt is the minimum acceptable floor. This drives the recommendation for Option A above.

At Accessibility sizes, both tokens scale without issues. The `Form` `Section` container wraps
text automatically, so multiline error messages should not clip.

#### 5.2.4 Multiline and Long-Error Clipping

Validation errors from `MedicationFormState.validationErrors` are short strings:
- "Name required."
- "Select an ingredient."
- "Dosage per unit must be greater than zero."
- "Add at least one scheduled time."

At any standard Dynamic Type size, these fit on one line. At Accessibility xxxLarge (47 pt
`.footnote`), "Dosage per unit must be greater than zero." may wrap to two lines. The `Section`
container handles this gracefully. Verify that no `lineLimit` is applied to the error text rows.
Currently there is none in `MedicationFormView` — confirm this remains true.

---

## 6. UX and Visual Design

### 6.1 Correct Glass-Layer Depth

Liquid Glass is defined in SPEC §9 as a monochromatic baseline where depth is established via
"subtle drop shadow + glass refraction, not via colored chrome." Two glass layers on the Add
medication sheet corrupt this by over-weighting the refraction and making the backdrop illegible.
The correct rendered result for the Add medication sheet is:

- The sheet's translucent surface allows the blurred backdrop (the Regimen list underneath) to
  read through as color-neutral depth information.
- The sheet handle is visible at 1× opacity.
- The `Form` rows within the sheet are legible against the single-layer glass surface.
- No visible "blurry grey wall" effect; the glass reads as genuinely translucent, not opaque.

For the Edit medication push, the glass surface provided by `.glassBackground()` on the form
should match the visual depth of the sheet presentation after the fix — both surfaces use a single
glass layer; the difference is whether it comes from the platform or the view modifier.

### 6.2 Nested Sheet Scrim and Legibility

When `NewIngredientView` is presented as a sheet from within `AddMedicationView`, iOS 26 renders
the outer sheet in a semi-dismissed visual state (shifted down, dimmed) to frame the inner sheet.
This is the correct platform behavior and should not be countered by any view-level modifier. The
correct outcome:

- The inner `NewIngredientView` sheet is fully legible.
- The outer `AddMedicationView` sheet is visually recessed but not opaque.
- No `.glassBackground()` on `NewIngredientView` (keep the current state — do not add glass here).

### 6.3 Error Text Semantic vs. High-Risk Color

The color discipline from CLAUDE.md is explicit: "Color is reserved for high-risk meds. Baseline
UI is monochromatic glass. Amber accent appears only on press-and-hold confirmations." Validation
error text uses `.red` — this is correct because it is a semantic indicator (form submission
blocked) belonging to the iOS affordance vocabulary, not a decorative accent. The amber
`highRiskAccent` must never appear on error text; it reads as "high-risk medication" not as
"form error."

In a future accessibility pass, error text may benefit from a leading symbol
(`Image(systemName: "exclamationmark.circle")`) for non-color differentiation. That is out of
scope for this issue — the color-only `.red` treatment is sufficient for Phase 3. Note it here
so the Phase 9 accessibility audit can pick it up.

---

## 7. Edge Cases and Failure Modes

### 7.1 iOS 26 Sheet Chrome Behavior Change

If Apple changes how `.sheet` applies glass in a future iOS 26 point release (e.g., removes the
default glass chrome, or makes it opt-in), the fix (suppressing `.glassBackground()` in sheet
context) would leave the Add medication form without any glass treatment. Mitigation: the
`appliesGlassBackground` parameter documents the rationale in a comment pointing to this issue,
so a future reader knows to revisit if the iOS 26 sheet chrome changes.

### 7.2 Simulator vs. Real Device Rendering

Glass refraction quality differs between the simulator and real hardware — the simulator
composites glass layers using a fixed blurred snapshot rather than real-time rendering. Double-
glass on a simulator may appear subtly different from double-glass on device. If the simulator
test passes but the PR reviewer sees stacking on real hardware, the fix direction (suppress the
view-level glass inside sheet context) remains correct; only the threshold for "acceptable single
layer" may differ slightly.

### 7.3 `interactiveDismissDisabled` and Sheet Behavior

`AddMedicationView` sets `.interactiveDismissDisabled(true)`. This does not affect glass rendering
but does prevent drag-to-dismiss on the outer sheet. When `NewIngredientView` is open,
`interactiveDismissDisabled` applies only to the outer sheet; the inner sheet retains standard
dismiss behavior. Verify that the glass scrim and dimming behavior is correct when the inner sheet
is dismissed while the outer sheet remains open.

### 7.4 Dynamic Type in Form Sections

SwiftUI `Form` sections do not constrain `Text` elements to a fixed height. Long error messages
at extreme Dynamic Type sizes will wrap gracefully. There is no clipping risk unless a `frame`
or `lineLimit` is added later. This spec does not introduce any such constraint.

### 7.5 Dark Mode System Red Contrast

In dark mode, `Color.red` resolves to a lighter red (`UIColor.systemRed` in dark mode is
approximately `#FF453A`). Against a dark glass background, the contrast ratio is adequate at
default Dynamic Type but must be spot-checked at xSmall. If contrast fails, the fix is to use
`.foregroundStyle(Color(UIColor.systemRed))` explicitly (which always resolves the semantic color
for the current appearance) rather than the SwiftUI `.red` alias, which already does this — so
this is primarily a labeling concern for the review checklist.

---

## 8. Testing and Regression Guards

### 8.1 Design Token Unit Tests (existing target: `PillBreakfastTests`)

Add a test to `PillBreakfastTests/DesignSystem/LiquidGlassThemeTests.swift` verifying the new
`errorText` builder once it is added:

```swift
@Test func errorTextBuilderAppliesFootnoteFont() {
    let text = "Name required."
    #expect(
        LiquidGlassTheme.Typography.errorText(text)
            == Text(text).font(LiquidGlassTheme.Typography.footnoteFont)
    )
}
```

This pins the token value and prevents a future change that silently drops the error text to
`captionFont`.

### 8.2 UI Test: Error Text Accessibility (target: `PillBreakfastUITests`)

Add a UI test in `PillBreakfastUITests` that:

1. Launches the app.
2. Navigates to the Regimen tab.
3. Taps the "Add medication" button to open the Add medication sheet.
4. Taps "Save" immediately (before filling any fields) to trigger validation.
5. Asserts that the first error text element exists and that its frame height is non-zero.

```swift
@MainActor
func testValidationErrorsAreVisible() throws {
    let app = XCUIApplication()
    app.launch()

    // Navigate to Regimen tab
    app.tabBars.buttons["Regimen"].tap()

    // Open the Add medication sheet
    let addButton = app.buttons["Add medication"]
    XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    addButton.tap()

    // Interact with the name field to set hasInteracted = true,
    // then clear it so validation fires
    let nameField = app.textFields["Name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    nameField.tap()
    nameField.typeText(" ")
    nameField.typeText(XCUIKeyboardKey.delete.rawValue)

    // The error section should now be visible
    let errorText = app.staticTexts["Name required."]
    XCTAssertTrue(errorText.waitForExistence(timeout: 3),
                  "Validation error text should appear after interaction")
    XCTAssertGreaterThan(errorText.frame.height, 0,
                         "Error text should have non-zero rendered height")
}
```

This test does not verify size in points (unavailable via XCTest accessibility frame on a dynamic
type scale), but it confirms the element is not zero-height (which would indicate clipping or
invisible rendering) and exists in the hierarchy (which would fail if the font were set to
zero-size or the view were collapsed).

### 8.3 Manual Snapshot Verification Protocol

Because `glassEffect()` renders differently on simulator vs. device and the automated test
environment is headless, the primary regression guard for glass-layer stacking is a set of
manual screenshots attached to the PR that resolves this issue. The required screenshots are
defined in Section 5.3 (Verification Protocol) below. These screenshots should be stored in
`plans/screenshots/issue-103/` and referenced in the closing PR description.

The project has no snapshot testing library (e.g., SnapshotTesting) as of Phase 3. Adding one
is a good candidate for the Phase 9 hardening pass. For now, the PR screenshots serve as the
visual regression baseline.

### 8.4 Which Test Target

All unit tests: `PillBreakfastTests` scheme on `iPhone 17, iOS latest` simulator.
All UI tests: `PillBreakfastUITests` scheme on `iPhone 17, iOS latest` simulator.

---

## 9. Risks and Open Questions

### 9.1 Does iOS 26 `.sheet` Always Apply Glass?

The issue assumes iOS 26 sheets apply glass at the presentation layer by default. This is
consistent with the Liquid Glass design language and with Apple's session materials ("Build with
Liquid Glass on watchOS", WWDC 2025), but the exact behavior of the iOS 26 sheet chrome needs
empirical verification on the simulator. If the sheet does not apply glass (i.e., it renders with
a plain blurred material rather than `glassEffect()`), then the current double-application may
produce a different artifact than described — one glass layer from the view plus one blur-only
layer from the sheet chrome. The fix direction (remove `.glassBackground()` from `MedicationFormView`
when in sheet context) is still correct in this scenario: the view-level glass would be adding
refraction on top of the sheet chrome's blur, which is still incorrect stacking.

### 9.2 SwiftUI `.if` Modifier Availability

The recommended fix uses a `.if(_:transform:)` view modifier. This is not in the SwiftUI
standard library. If the project does not already have it in `Shared/DesignSystem/`, it must be
added. Confirm before implementing.

### 9.3 Future Multi-Component Support

`MedicationFormView` currently supports one ingredient component. SPEC §6.1 and the TODO in
`MedicationFormState.apply(to:in:)` indicate multi-component support (combo products) is planned.
When that lands, the form may gain additional sheets or pickers; the glass-layer policy established
here (no `.glassBackground()` inside a `.sheet` context) should be applied to any new sub-flows
at that time.

### 9.4 `NewIngredientView` is Private

`NewIngredientView` is declared `private` inside `MedicationFormView.swift`. This limits unit
testability. It does not affect this spec's verification, but note it for the Phase 9 audit.

---

## 10. Decomposition Hints

If the implementer determines that the issues need to be addressed in separate child issues:

| Child issue | Scope | Who |
|---|---|---|
| 103a: Fix double-glass in AddMedicationView | Remove `.glassBackground()` from `MedicationFormView` in sheet context; add `appliesGlassBackground` parameter or conditional | Implementation Specialist |
| 103b: Add `errorText` Typography builder | Add `LiquidGlassTheme.Typography.errorText(_:)` token; update `MedicationFormView` call site; add unit test | Implementation Specialist |
| 103c: UI test for validation error visibility | `PillBreakfastUITests` — error text existence and non-zero height at default Dynamic Type | Implementation Specialist |

In practice this is small enough for a single issue/PR. Only split if the glass fix requires
more investigation (e.g., if the iOS 26 sheet chrome behavior is not what the issue assumes).

---

## 11. Acceptance Criteria / Done-Done

All of the following must be true before this issue closes:

1. **Single glass layer on the Add medication sheet.** On an iPhone 17 simulator running iOS 26,
   the Add medication sheet displays one glass layer. There is no visible over-blur, grey-mud
   effect, or excessively heavy scrim on the sheet handle. A screenshot is attached to the PR.

2. **Visual consistency between sheet and push presentations.** The Add medication sheet
   (after the fix) and the Edit medication push share the same perceived glass depth. A
   side-by-side screenshot comparison is attached to the PR.

3. **Nested sheet legibility.** The New Ingredient sheet (presented from inside the Add medication
   sheet) is fully legible. The outer sheet recesses correctly when the inner sheet is open. A
   screenshot is attached to the PR.

4. **Error text uses `footnoteFont` or the new `errorText` token.** The validation-error rows in
   `MedicationFormView` render at `LiquidGlassTheme.Typography.footnoteFont` (13 pt default) or
   the new `errorText` helper that maps to the same token. The `captionFont` (12 pt) is not used
   for error text. Confirmed by code review and the new unit test.

5. **Error text legibility across Dynamic Type.** Manual verification on the iPhone 17 simulator
   at xSmall, default Large, and Accessibility Large Dynamic Type categories confirms that error
   text is legible at all three sizes in both light and dark mode. Screenshots attached.

6. **Error text color is `.red`, not `highRiskAccent`.** The amber accent does not appear on any
   error text. Confirmed by code review.

7. **Unit test passes.** `LiquidGlassThemeTests.errorTextBuilderAppliesFootnoteFont` passes in
   the `PillBreakfastTests` scheme on iPhone 17.

8. **UI test passes.** `testValidationErrorsAreVisible` passes in the `PillBreakfastUITests`
   scheme on iPhone 17.

9. **Both schemes remain green.** `xcodebuild build` for both `PillBreakfast` (iOS) and
   `PillBreakfast Watch App Watch App` (watchOS) targets succeeds. `pre-commit run --all-files`
   is clean.

10. **Phase 3 gate: visual review.** The Regimen tab and its Add/Edit forms look like watchOS 26
    native UI, not a port of iOS chrome. Specifically: glass is translucent (not opaque), the
    color palette is monochromatic except for any high-risk indicator glyphs, and the form reads
    cleanly at both light and dark appearances.

---

## 12. References

- `PillBreakfast/RegimenTab/MedicationFormView.swift` — form body, glass modifiers, error section
- `PillBreakfast/RegimenTab/AddMedicationView.swift` — sheet host, `.presentationDetents([.large])`, `.interactiveDismissDisabled(true)`
- `PillBreakfast/RegimenTab/EditMedicationView.swift` — push host, no sheet chrome
- `PillBreakfast/RegimenTab/MedicationFormState.swift` — `validationErrors` string generation
- `PillBreakfast/RegimenTab/RegimenListView.swift` — parent with `.sheet(isPresented: $showingAdd)`
- `PillBreakfast/RegimenTab/RegimenTabHostView.swift` — root `NavigationStack`
- `Shared/DesignSystem/View+GlassBackground.swift` — `.glassBackground()` implementation
- `Shared/DesignSystem/LiquidGlassTheme.swift` — all typography, color, elevation tokens
- `Shared/DesignSystem/Typography.swift` — `Text`-builder helpers
- `PillBreakfastTests/DesignSystem/LiquidGlassThemeTests.swift` — existing token tests
- `PillBreakfastUITests/PillBreakfastUITests.swift` — existing UI test scaffold
- SPEC §6.1 — iPhone Regimen tab design
- SPEC §9 — Liquid Glass design language
- SPEC §10 Phase 3 — gate: "looks like a watchOS 26 native app, not a port of iOS chrome"
- CLAUDE.md — "Color is reserved for high-risk meds. Baseline UI is monochromatic glass."
- Apple WWDC 2025: "Meet Liquid Glass", "Build with Liquid Glass on watchOS"
