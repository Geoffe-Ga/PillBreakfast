# SPEC — Issue #61: App Icons (1024 Master + All Derived Sizes)

| Field | Value |
|---|---|
| Issue | #61 |
| Phase | 9 — Hardening & Submission Prep |
| Labels | `spec-decomposition`, `polish`, `phase-9-hardening` |
| Status | Draft |
| Date | 2026-06-07 |
| Parent epic | #10 |
| Related issues | #62 (screenshots depend on icon being in place), #66 (soak test uses the shipped icon) |

---

## 1. Summary

Produce a single 1024×1024 master icon that embodies the Liquid Glass / monochromatic glass
aesthetic defined in SPEC §9 and `Shared/DesignSystem/LiquidGlassTheme.swift`, derive all required
size variants for both the iOS and watchOS asset catalogs, and verify the builds pass Xcode's asset
catalog validation. Three appearance variants are required for the iOS target (standard, dark,
tinted); one universal variant is required for the watchOS target.

---

## 2. Problem Statement / Motivation

Both asset catalogs currently contain placeholder entries with no image files — `Contents.json`
declares the required idiom/appearance slots but every `filename` field is absent. Xcode's asset
catalog validator will fail at submission time, and the App Store Connect uploader will reject the
binary. This must be resolved before #62 (screenshots) can be completed, because screenshots are
captured with the real icon visible on the home screen and watch app grid.

---

## 3. Goals & Non-Goals

**Goals:**
- Design direction aligned with SPEC §9 (monochromatic, glass-first, restraint — no amber for the
  icon; amber is reserved for the in-app high-risk confirmation gesture)
- A single canonical 1024×1024 PNG master in `Submission/assets/` used as the derivation source
  of truth
- All required size/appearance combinations populated for both targets
- `xcodebuild` asset catalog validation passes clean on both schemes
- Dark and tinted variants for iOS follow the iOS 26 icon appearance system

**Non-Goals:**
- Animated icon (not supported on either platform at v1)
- App Store marketing artwork beyond the icon (that belongs to #62)
- watchOS complication images (those are separate WidgetKit assets handled in Phase 7)
- Physical icon production — this spec instructs, it does not generate pixels

---

## 4. Background & Current State

### Asset catalog state

`PillBreakfast/Assets.xcassets/AppIcon.appiconset/Contents.json` declares three slots:
- `idiom: universal`, `platform: ios`, `size: 1024x1024` (standard)
- same with `appearance: luminosity / dark`
- same with `appearance: luminosity / tinted`

`PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json` declares one slot:
- `idiom: universal`, `platform: watchos`, `size: 1024x1024`

No `filename` keys are present in either file. Xcode 26 uses a single-size asset catalog format
for both platforms (the OS derives the display sizes at runtime from the 1024 master), but the
PNG files themselves must be provided or the catalog fails validation.

### iOS 26 icon appearance system

iOS 26 introduced three icon appearance variants that replace the legacy multi-size matrix:

| Appearance | Slot name | Usage |
|---|---|---|
| Standard (light) | no `appearances` key | Light mode; default for older OS |
| Dark | `luminosity: dark` | Dark mode home screen |
| Tinted | `luminosity: tinted` | User-chosen monochrome tint overlay |

All three are 1024×1024 PNG. The OS handles scaling to every display size. This is the current
`Contents.json` format Xcode 26 generates and is what the catalog already declares.

### watchOS 26 icon format

watchOS 26 also uses a single 1024×1024 universal slot — no separate sizes. The watch does not
support dark/tinted icon variants; only the one `platform: watchos` entry is needed.

### Design system context

`LiquidGlassTheme.Colors` has exactly one named color: `highRiskAccent` (warm amber,
`rgb(0.96, 0.66, 0.27)`). The design language comment reads: "There is intentionally no
`accentColor`; baseline UI stays glass + mono." The icon must respect this — no amber anywhere on
the icon. The icon is not a moment of danger; it is the app's resting face.

---

## 5. Detailed Design / Plan

### 5.1 Design direction

The icon mark should communicate: a pill, a watch, or the act of a deliberate single tap — any of
these reads as "medication tracker for Apple Watch." Constraints from SPEC §9:

- **Monochromatic.** The standard variant uses white/near-white forms on a dark translucent or
  deep charcoal ground, or a light ground with charcoal/black forms. Liquid Glass implies
  translucency but an app icon cannot use transparency at the edges (it is composited into a rounded
  rect by the OS) — the illusion of glass is achieved through highlights, inner shadows, and subtle
  gradients within the 1024 canvas.
- **Restraint.** One dominant shape. No multiple elements competing for attention. The name
  "PillBreakfast" is not inscribed in the icon — the app name appears below the icon on the home
  screen.
- **No amber.** Amber is strictly reserved for the in-app high-risk press-and-hold ring per SPEC §9
  and CLAUDE.md. Using amber on the icon would undermine this semantic contract.
- **No checklist.** A grid of pills would imply "list app." The design should evoke a single,
  confident moment.

Suggested mark: a single pill capsule rendered with a glass-highlight sheen — left half slightly
lighter, right half slightly darker, a thin specular line across the shoulder. Alternatively: a
minimal wrist silhouette (no screen detail) with a single pill above it. Both options are clean with
one dominant shape.

The dark variant darkens the ground and brightens the glass highlights. The tinted variant should
use a fully grayscale treatment so the OS tint overlay (user-chosen color, iOS 26 system feature)
reads correctly — tinted icons work by desaturating and recoloring, so the tinted master should have
no hue information.

### 5.2 Master derivation workflow

```
Master file: Submission/assets/AppIcon-1024-standard.png   (1024×1024, sRGB, no transparency)
Dark variant: Submission/assets/AppIcon-1024-dark.png      (1024×1024, sRGB, no transparency)
Tinted variant: Submission/assets/AppIcon-1024-tinted.png  (1024×1024, grayscale-safe, no transparency)
Watch master: Submission/assets/AppIcon-1024-watch.png     (1024×1024, sRGB, no transparency)
```

The watch master can be identical to the standard iOS master or a subtle crop/weight adjustment —
the watch icon renders at 50–55pt on the watch app grid; fine detail at the edges of the standard
variant may be lost at that scale.

**Tooling.** Any of the following are acceptable for PNG export and derivation:

- Figma / Sketch export at 1024×1024, PNG-24, no alpha channel on the background layer
- `sips` (macOS built-in) for format conversion: `sips -s format png input.png --out output.png`
- `iconutil` is *not* needed — iOS/watchOS asset catalogs use flat PNG files, not `.icns`

There is no tooling script to generate multiple sizes from the master; the catalog declares only
1024×1024 for both platforms. Derivation from the master means: produce the three appearance
variants from the design source, not produce multiple pixel sizes.

### 5.3 Asset catalog population

**iOS target** (`PillBreakfast/Assets.xcassets/AppIcon.appiconset/`):

The `Contents.json` already declares the three correct entries. The implementer adds `filename`
keys pointing to the three PNG files placed into the same directory:

```json
{
  "images": [
    {
      "filename": "AppIcon-1024.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    },
    {
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "filename": "AppIcon-1024-dark.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    },
    {
      "appearances": [{ "appearance": "luminosity", "value": "tinted" }],
      "filename": "AppIcon-1024-tinted.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

**watchOS target** (`PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/`):

```json
{
  "images": [
    {
      "filename": "AppIcon-1024-watch.png",
      "idiom": "universal",
      "platform": "watchos",
      "size": "1024x1024"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

### 5.4 Verification steps

1. `xcodebuild build` on both schemes — asset catalog validation runs automatically during build.
2. Install on a paired simulator (iPhone 17 + Apple Watch Series 11 46mm). Verify:
   - iPhone: icon appears on home screen in light mode (standard variant)
   - iPhone: switch to dark mode — dark variant appears
   - iPhone: Settings > Accessibility > Display & Text Size > "Color Tint" or dark mode icon
     tinting — tinted variant reads correctly (no hue saturation visible under tint)
   - Watch: icon appears in watch app grid
3. PR body must include screenshots of both surfaces showing the icon.

---

## 6. Assets & Deliverables

| Path | Description |
|---|---|
| `Submission/assets/AppIcon-1024-standard.png` | Standard (light) master, 1024×1024 |
| `Submission/assets/AppIcon-1024-dark.png` | Dark appearance master, 1024×1024 |
| `Submission/assets/AppIcon-1024-tinted.png` | Tinted/grayscale master, 1024×1024 |
| `Submission/assets/AppIcon-1024-watch.png` | watchOS master, 1024×1024 |
| `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | iOS standard PNG in catalog |
| `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png` | iOS dark PNG in catalog |
| `PillBreakfast/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png` | iOS tinted PNG in catalog |
| `PillBreakfast/Assets.xcassets/AppIcon.appiconset/Contents.json` | Updated with `filename` keys |
| `PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-watch.png` | watchOS PNG in catalog |
| `PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json` | Updated with `filename` key |

The `Submission/assets/` source masters are the single derivation source of truth. The catalog
copies are byte-identical to the corresponding master (no additional processing during copy).

---

## 7. Edge Cases & Failure Modes

**Alpha channel present.** iOS app icons must not have an alpha channel. Xcode will warn during
asset validation. Use PNG-24, not PNG-32. Verify: `file AppIcon-1024.png` should report "RGB" not
"RGBA". With `sips`: `sips -g hasAlpha AppIcon-1024.png` should return `hasAlpha: NO`.

**Color profile mismatch.** Export in sRGB. Using a wide-gamut (Display P3) profile is technically
allowed but can produce unexpected color rendering on non-P3 devices. To be safe, convert explicitly:
`sips -m /System/Library/ColorSync/Profiles/sRGB\ Profile.icc input.png --out output.png`

**Tinted variant with residual saturation.** If the tinted master has visible hue, the iOS tint
overlay will fight it. Verify: open in Preview, Image > Adjust Color, check that Saturation reads
near-zero across the image.

**Watch icon too visually dense at small size.** The watch app grid renders the icon at approximately
50–55pt (100–110px on the retina display). Fine detail and thin strokes at the edges of the 1024
canvas will merge at this scale. Test by scaling a preview to 110×110 in any image viewer before
committing.

**`Contents.json` edited by Xcode.** If the catalog is opened in Xcode after manual edits, Xcode
may rewrite `Contents.json` in a way that reorders keys. This is benign as long as `filename` values
are preserved. Always inspect the git diff after any Xcode asset catalog interaction.

---

## 8. Verification / Acceptance Criteria

- [ ] `xcodebuild build -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'` exits 0 with no asset catalog warnings or errors
- [ ] `xcodebuild build -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'` exits 0 with no asset catalog warnings or errors
- [ ] Icon is visible on iPhone 17 simulator home screen (light mode)
- [ ] Icon renders correctly in dark mode (not just the system-inverted version of the standard; the dark variant is used)
- [ ] Icon renders legibly on the watch app grid at native scale
- [ ] PR includes home screen screenshot (iPhone) and app grid screenshot (watch) with the new icon visible
- [ ] All three PNG masters are present in `Submission/assets/`
- [ ] No alpha channel on any of the four PNGs (`sips -g hasAlpha` returns `NO`)
- [ ] `pre-commit run --all-files` is clean (no byte-order markers, secret scan passes)
- [ ] Existing tests continue to pass (no code change; this is a pure asset change)

---

## 9. Risks & Open Questions

**Risk: design review.** The issue body says "Engineer picks the exact mark; design review is part
of the PR." This means the PR must include a design rationale comment explaining the mark choice and
how it honors SPEC §9. The reviewer must explicitly sign off on the visual direction before merge.

**Risk: Xcode 26 asset catalog format changes.** The current `Contents.json` was Xcode-generated.
If a future Xcode 26 beta changes the expected schema, `xcodebuild` will surface it during build.
Do not hand-edit around a validator error — update the `Contents.json` to match what Xcode expects
and document the delta.

**Open question: should the iOS and watchOS marks differ?** The current plan allows an identical
or lightly adjusted version. This is an open design decision for the implementing engineer to resolve
in the PR. The safe default is identical marks; diverge only if small-size legibility tests show the
watch version needs adjustment.

**Open question: App Store Connect 1024×1024 submission copy.** App Store Connect still expects a
1024×1024 PNG submitted separately via the uploader (separate from the in-app icon). The `Submission/assets/AppIcon-1024-standard.png` master serves double duty as this upload artifact.
Confirm during submission prep that the standard variant is used (not dark or tinted) for the
App Store listing thumbnail.

---

## 10. Decomposition Hints

This issue is small enough to execute as a single PR. If design iteration is anticipated, a
two-step decomposition is reasonable:

1. Child A: Design review only — produce the four source PNGs and post them to an issue comment for
   sign-off before touching any asset catalog files.
2. Child B: Catalog population — take the signed-off PNGs, slot them in, update `Contents.json`,
   verify builds.

This avoids a round-trip CI cycle on purely visual feedback.

---

## 11. References

- SPEC §9 — Liquid Glass design language (monochromatic, amber reserved for high-risk only)
- SPEC §10 Phase 9 — submission prep gate
- CLAUDE.md — "Color is reserved for high-risk meds" convention
- `Shared/DesignSystem/LiquidGlassTheme.swift` — `highRiskAccent` is the sole named color
- `PillBreakfast/Assets.xcassets/AppIcon.appiconset/Contents.json` — current catalog state
- `PillBreakfast Watch App Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json` — current watch catalog state
- Apple HIG — [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) (iOS and watchOS sections)
- Apple HIG — [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) (icon dark variant guidance)
- WWDC 2025 — "Meet Liquid Glass" (design language reference)
- Issue #62 — screenshots depend on icon; merge #61 first
