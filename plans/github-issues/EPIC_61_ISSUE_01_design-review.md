## Role

You are a product designer producing the v1 PillBreakfast app-icon mark in the Liquid Glass / monochromatic-glass aesthetic. Your deliverable is the four canonical source PNG masters plus a design rationale posted for reviewer sign-off — **no asset-catalog files are touched in this issue.**

## Goal

Design and export the four 1024×1024 source masters into `Submission/assets/` (standard, dark, tinted for iOS; one watch master), each respecting SPEC §9 restraint (one dominant shape, monochromatic, **no amber**), and post them to the #61 issue with a written rationale so the reviewer can sign off on the visual direction before any catalog round-trip. This isolates purely-visual feedback from the build/validation step (#61 child 2).

## Context

- **Parent epic:** #61.
- **Predecessors:** none — this is the first step of the icon work; it gates the catalog-population child.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-61_app-icons.md` §5.1 (design direction), §5.2 (master derivation workflow), §7 (alpha/sRGB/tinted-desaturation/small-size edge cases), §9 (design-review risk), §10 (decomposition hint: design review as its own step).
- **Files involved:**
  - `Submission/assets/AppIcon-1024-standard.png` (new) — standard/light master, 1024×1024, sRGB, no alpha.
  - `Submission/assets/AppIcon-1024-dark.png` (new) — dark-appearance master (darker ground, brighter glass highlights).
  - `Submission/assets/AppIcon-1024-tinted.png` (new) — fully desaturated/grayscale-safe master for the iOS tint overlay.
  - `Submission/assets/AppIcon-1024-watch.png` (new) — watchOS master (identical to standard, or a subtle weight/crop adjustment for ~50–55pt grid legibility).
  - `Shared/DesignSystem/LiquidGlassTheme.swift` (read-only reference) — `highRiskAccent` is the sole named color; "no `accentColor`; baseline UI stays glass + mono."
- **Prior decisions (locked):**
  - **No amber anywhere on the icon** — amber is reserved for the in-app high-risk ring (SPEC §9, CLAUDE.md). Using it on the icon would undermine that semantic contract.
  - One dominant shape; no pill grid (reads "list app"); no inscribed app name.
  - Glass illusion comes from highlights / inner shadows / subtle gradients *inside* the canvas — the icon cannot be edge-transparent (the OS composites it into a rounded rect).
  - Tinted master has **no hue information** (verify Saturation ≈ 0 across the image) or the OS tint overlay fights it.

## Output Format

A PR (or issue-comment package, per the reviewer's preference) containing:

- [ ] The four PNG masters in `Submission/assets/`, each 1024×1024, sRGB, **no alpha channel** (`sips -g hasAlpha <file>` returns `hasAlpha: NO`; `file <file>` reports RGB not RGBA).
- [ ] The tinted master verified as effectively grayscale (Saturation near zero across the image).
- [ ] A small-size legibility note for the watch master (preview scaled to ~110×110 px — fine strokes/edge detail must not merge).
- [ ] A **design rationale** posted to #61: which mark was chosen (pill capsule vs. wrist + pill), and how it honors SPEC §9 monochromatic restraint and the no-amber rule. Explicit reviewer sign-off on the visual direction is required before the catalog-population child proceeds.

## Examples

The derivation source-of-truth layout this child must produce (SPEC §5.2):

```
Submission/assets/AppIcon-1024-standard.png   # 1024×1024, sRGB, no transparency
Submission/assets/AppIcon-1024-dark.png       # 1024×1024, sRGB, no transparency (darker ground, brighter glass)
Submission/assets/AppIcon-1024-tinted.png     # 1024×1024, grayscale-safe, no transparency
Submission/assets/AppIcon-1024-watch.png      # 1024×1024, sRGB, no transparency
```

Verification snippet the PR should show passing for each file:

```bash
sips -g hasAlpha Submission/assets/AppIcon-1024-standard.png   # -> hasAlpha: NO
file Submission/assets/AppIcon-1024-tinted.png                 # -> ... RGB ...
```

## Constraints

**Scope fence:** Source masters + rationale only. **Do not** edit either `AppIcon.appiconset/Contents.json`, **do not** copy PNGs into the catalogs, and **do not** add `filename` keys — that is the catalog-population child (#61 child 2). No code changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The app continues to build and run with its current placeholder catalog state — this child adds only source files under `Submission/assets/`; it changes nothing the build references, so both schemes remain green throughout.

## Done-Done

- [ ] All four masters present in `Submission/assets/`, 1024×1024, sRGB, no alpha (`sips -g hasAlpha` returns `NO`); tinted master verified desaturated.
- [ ] Design rationale posted to #61 and the reviewer has explicitly signed off on the visual direction.
- [ ] `pre-commit run --all-files` is clean (PNGs included; secret scan passes).
- [ ] PR opened with `Closes #<this issue>` and `Refs #61`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`
