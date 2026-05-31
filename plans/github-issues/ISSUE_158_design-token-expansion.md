## Role

You are a senior SwiftUI engineer extending `LiquidGlassTheme` so downstream polish PRs have a richer design vocabulary without scattering magic numbers.

## Goal

Expand `LiquidGlassTheme` with four new token families — typography hierarchy, elevation/shadow, corner radius, and motion curves — so the visual-polish PRs (#159–#165) can compose from named tokens instead of one-off values. The new vocabulary stays inside the project's monochromatic constraint: **no new colors**, no accent variants. Polish comes from typography rhythm, depth, and motion, not from color.

## Context

- **Parent epic:** #4 (Phase 3 — High-Risk Confirmation + Liquid Glass First Pass).
- **SPEC sections:** §9 (Visual Design — Liquid Glass).
- **Files involved:**
  - `Shared/DesignSystem/LiquidGlassTheme.swift` — add new token families.
  - `Shared/DesignSystem/Typography.swift` — add builder functions for the new typography roles.
  - `Shared/DesignSystem/View+GlassBackground.swift` — likely add elevation modifiers.
  - New test target file `PillBreakfastTests/DesignSystem/LiquidGlassThemeTests.swift` (or similar) — pin the token values so a future refactor can't silently drift them.

### Token families to add

- **Typography roles** (current set: title / medicationName / dosage / caption):
  - `displayFont` — SF Pro Rounded, `.largeTitle`, `.bold` — for "hero" copy (the right-now dose card, the success state's "All caught up").
  - `headlineFont` — SF Pro Rounded, `.headline`, `.semibold` — for section headers on iPhone.
  - `footnoteFont` — SF Pro Rounded `.footnote` for tertiary labels.
  - Update `Typography.swift` builders (`display(_:)`, `headline(_:)`, `footnote(_:)`).

- **Elevation tokens** — `.shadow` parameters as a named struct:
  - `Elevation.flat` (no shadow — default).
  - `Elevation.raised` (subtle shadow for cards atop glass — small radius, ~6, y-offset ~2, opacity ~0.08).
  - `Elevation.floating` (modal/sheet shadow — larger radius ~16, y-offset ~6, opacity ~0.12).
  - Provide a `.elevation(_:)` view modifier so call sites write `.elevation(.raised)`.

- **Corner radius** — discrete radii rather than per-component magic:
  - `CornerRadius.tight: 6` — small chips / inline badges.
  - `CornerRadius.standard: 12` — buttons, rows.
  - `CornerRadius.card: 20` — hero cards, sheets.

- **Motion curves** — spring presets for the polish PRs to reach for:
  - `Motion.snappy` (`.snappy(duration: 0.25, extraBounce: 0.1)`) for taps/confirmations.
  - `Motion.gentle` (`.smooth(duration: 0.35)`) for screen transitions.
  - `Motion.dramatic` (`.bouncy(duration: 0.5, extraBounce: 0.2)`) for success/celebration states.

## Output Format

A single PR containing:

- [ ] `LiquidGlassTheme.Typography` adds `displayFont`, `headlineFont`, `footnoteFont` constants. `Typography.swift` adds matching `display(_:)`, `headline(_:)`, `footnote(_:)` builders.
- [ ] `LiquidGlassTheme.Elevation` enum exposing `flat`, `raised`, `floating` with named shadow parameters. New `.elevation(_:)` view modifier in `View+GlassBackground.swift` (or a sibling file).
- [ ] `LiquidGlassTheme.CornerRadius` enum (`tight`, `standard`, `card`) with `CGFloat` values.
- [ ] `LiquidGlassTheme.Motion` enum exposing the three named animation presets.
- [ ] Token-value tests: confirm the typography font sizes/weights, the elevation shadow tuples, the corner radii, and the motion duration/bounce values match the spec above. Tests are pure value assertions — they catch silent drift, not visual quality.
- [ ] Doc comments on each token explain *why* (e.g., why `displayFont` is `.largeTitle` and not `.title` — it's the hero typography for the watch's tap-through card).

## Constraints

**Scope fence:** Tokens and modifiers only. **No** changes to consuming surfaces yet (those land in #159–#165). **Absolutely no new colors** — the high-risk amber stays the only color in the system.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Existing surfaces continue to compile and render unchanged — new tokens are additive.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass.
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean.
- [ ] App builds and runs on the paired simulator pair.
- [ ] PR opened with `Refs #4` and `Closes #<this issue>`.

## Labels

`spec-decomposition`, `design-system`, `polish`, `phase-3-high-risk`.
