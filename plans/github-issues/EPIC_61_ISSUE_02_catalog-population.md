## Role

You are an iOS/watchOS build engineer slotting the signed-off icon masters into both asset catalogs and proving the builds validate clean. This is a mechanical, validation-driven issue — the design is already decided in #61 child 1.

## Goal

Copy the four sign-off masters byte-identically from `Submission/assets/` into the iOS and watchOS `AppIcon.appiconset` directories, add the `filename` keys to both `Contents.json` files (preserving the existing Xcode-generated slot declarations), and verify `xcodebuild` asset-catalog validation passes clean on both schemes with the correct appearance rendering on a paired simulator.

## Context

- **Parent epic:** #61.
- **Predecessors:** #61 child 1 (design review) — the four masters in `Submission/assets/` must be signed off before this child starts.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-61_app-icons.md` §5.3 (catalog population — exact `Contents.json` shapes), §5.4 (verification steps), §6 (deliverables table), §7 (alpha/sRGB/Xcode-rewrite edge cases), §8 (acceptance criteria).
- **Files involved:**
  - `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (new — byte-identical copy of `Submission/assets/AppIcon-1024-standard.png`).
  - `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png` (new — copy of the dark master).
  - `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png` (new — copy of the tinted master).
  - `PillBreakfast/Assets.xcassets/AppIcon.appiconset/Contents.json` (edit — add three `filename` keys; the three slot declarations already exist).
  - `PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-watch.png` (new — copy of the watch master).
  - `PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json` (edit — add the single `filename` key).
- **Prior decisions (locked):**
  - The catalog copies are **byte-identical** to the `Submission/assets/` masters — no additional processing during copy.
  - iOS slots: `universal/ios/1024x1024` ×3 — standard (no `appearances`), `luminosity: dark`, `luminosity: tinted`. watchOS slot: a single `universal/watchos/1024x1024`.
  - If Xcode reorders `Contents.json` keys when the catalog is opened, that is benign **as long as `filename` values are preserved** — always inspect the git diff after any Xcode asset interaction. Do **not** hand-edit around a validator error; update `Contents.json` to match what Xcode 26 expects and document any delta.

## Output Format

A single PR containing:

- [ ] The four catalog PNGs copied in (three iOS, one watch), byte-identical to the `Submission/assets/` masters.
- [ ] iOS `Contents.json` updated with the three `filename` keys mapped to the correct appearance slots (standard / dark / tinted).
- [ ] watchOS `Contents.json` updated with its single `filename` key.
- [ ] Both schemes build with **zero asset-catalog warnings or errors**.
- [ ] PR body includes: iPhone home-screen screenshot (light + dark variants visible), watch app-grid screenshot, and confirmation that the tinted variant reads cleanly under the OS tint with no residual hue.

## Examples

The exact iOS `Contents.json` target shape (SPEC §5.3):

```json
{
  "images": [
    { "filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" },
    { "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "filename": "AppIcon-1024-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" },
    { "appearances": [{ "appearance": "luminosity", "value": "tinted" }],
      "filename": "AppIcon-1024-tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

watchOS `Contents.json`:

```json
{
  "images": [
    { "filename": "AppIcon-1024-watch.png", "idiom": "universal", "platform": "watchos", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

## Constraints

**Scope fence:** Catalog population + validation only. **Do not** redesign or re-export the masters (that was child 1); if a master is wrong, kick it back to child 1 rather than editing pixels here. No Swift changes.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** At the end of this issue both schemes build and run on the paired simulator with the real icon on the home screen and watch grid — the same demoable state as before, now with a validated icon instead of placeholders.

## Done-Done

- [ ] iOS + watch schemes build & all tests pass via the xcodebuild commands in CLAUDE.md, with **no asset-catalog warnings or errors**.
- [ ] Icon visible on the iPhone 17 simulator home screen (light), correct dark variant in dark mode, legible on the watch app grid; tinted variant reads cleanly under the OS tint.
- [ ] No alpha channel on any catalog PNG (`sips -g hasAlpha` returns `NO`); catalog copies byte-identical to `Submission/assets/`.
- [ ] `pre-commit run --all-files` is clean (asset/metadata files included).
- [ ] PR opened with `Closes #<this issue>` and `Refs #61`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`
