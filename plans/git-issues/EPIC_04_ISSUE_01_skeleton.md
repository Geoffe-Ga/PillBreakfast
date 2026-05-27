## Role

You are a senior SwiftUI engineer building the project's reusable design system. You understand watchOS 26's Liquid Glass APIs (`.glassEffect()`, Material backgrounds) and the discipline of *not* hard-coding colors and fonts at call sites.

## Goal

Add a `LiquidGlassTheme` module in `Shared/DesignSystem/` exposing typed design tokens — colors (monochromatic baseline + the high-risk amber), typography (SF Pro Rounded / Display per SPEC §9), and Material wrappers — and apply it as a smoke test to the watch `RightNowView` background. Subsequent issues in EPIC 04 propagate it across the tap-through queue, success state, and iPhone Regimen tab.

## Context

- **Parent epic:** #4
- **Predecessor issue(s):** #EPIC_03_ISSUE_06_NUMBER (full EPIC 03 must be merged; we need a working tap-through to skin).
- **SPEC section:** `plans/SPEC.md` §9 (Liquid Glass Design Language, lines 376-388).
- **Files involved (new):**
  - `Shared/DesignSystem/LiquidGlassTheme.swift` — typed tokens.
  - `Shared/DesignSystem/View+GlassBackground.swift` — `View` extension wrapping `.glassEffect()` with a fallback for older OS / unit-test contexts.
  - `Shared/DesignSystem/Typography.swift` — `Font` constants for medication names (`.title`-shaped SF Pro Rounded) and dosage figures (`.title3`-shaped SF Pro Display, monospaced digits).
- **Files updated:** `WatchApp Watch App/RootView/RightNowView.swift` — apply `.glassBackground()` to demonstrate the API.
- **Prior decisions (locked):**
  - **Color is reserved for high-risk meds.** The token for the high-risk accent is named explicitly: `LiquidGlassTheme.Colors.highRiskAccent`. There is no general-purpose `.accentColor` exposed. CLAUDE.md.
  - SF Pro Rounded for names, SF Pro Display for dosage figures. SPEC §9.
  - **Negative space is part of the design.** The tokens include explicit padding/spacing constants (`Spacing.compact = 8`, `.standard = 16`, `.generous = 24`).
- **State of the world:** EPIC 03 is complete. Watch tap-through works in default SwiftUI chrome.

## Output Format

A single PR containing:

- [ ] `LiquidGlassTheme` enum (or struct) with nested `Colors`, `Typography`, `Spacing`, `Materials` namespaces, each containing the tokens.
- [ ] `View+GlassBackground` extension: `func glassBackground() -> some View` that resolves to the `.glassEffect()` API on watchOS 26 / iOS 26 and to a `Material.ultraThin` fallback otherwise. Document the fallback.
- [ ] `Typography` namespace with `func medicationName(_ text: String) -> Text` and `dosage(...)` helpers that bake in the font and rounded style.
- [ ] `RightNowView` calls `.glassBackground()` on its outer container.
- [ ] Unit tests where possible (mostly compile-time checks; snapshot tests are EPIC_04_ISSUE_05).

## Examples

```swift
public enum LiquidGlassTheme {
    public enum Colors {
        public static let primaryText: Color = .primary
        public static let secondaryText: Color = .secondary
        public static let highRiskAccent: Color = Color(red: 0.96, green: 0.66, blue: 0.27) // warm amber
        // No general-purpose accent. Color discipline (SPEC §9) is enforced
        // by not exposing one.
    }
    public enum Typography {
        public static let medicationName: Font = .system(.title, design: .rounded, weight: .semibold)
        public static let dosage: Font = .system(.title3, design: .default, weight: .medium).monospacedDigit()
    }
    public enum Spacing {
        public static let compact: CGFloat = 8
        public static let standard: CGFloat = 16
        public static let generous: CGFloat = 24
    }
}
```

`View+GlassBackground.swift`:

```swift
public extension View {
    func glassBackground() -> some View {
        if #available(watchOS 26.0, iOS 26.0, *) {
            return AnyView(self.glassEffect())
        } else {
            return AnyView(self.background(.ultraThinMaterial))
        }
    }
}
```

The `if #available` here is **not** a `@available(*, deprecated)` shim — it's a legitimate version-compat branch the documented exception allows. Document the alternative considered (linking watchOS 25 fallback) and the review date.

## Constraints

**Scope fence:** Do not propagate the theme to every screen yet — that's EPIC_04_ISSUE_03. Do not add the press-and-hold ring — EPIC_04_ISSUE_02. Do not surface the gesture-duration setting — EPIC_04_ISSUE_04.

**Color discipline is part of the API.** Do not expose a generic `accentColor` token. The only color anywhere in the design system is `Colors.highRiskAccent`, and the next issue is the only place it's used.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Watch `RightNowView` now has a glass background; everything else unchanged.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #4` and `Closes #EPIC_04_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-3-high-risk`, `design-system`.
