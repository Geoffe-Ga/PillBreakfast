# Epic — #61 App Icons (1024 master + all derived appearance variants)

## Outcome

Both asset catalogs ship a real, validated app icon in the Liquid Glass / monochromatic-glass aesthetic (SPEC §9). A single 1024×1024 master drives three iOS appearance variants (standard / dark / tinted) and one watchOS universal variant; `xcodebuild` asset-catalog validation passes clean on both schemes, and the icon renders correctly on the iPhone home screen (light + dark + tinted) and the watch app grid. This unblocks #62 (screenshots are captured with the real icon visible).

## Spec sections

- `plans/2026-06-07_SPEC_ISSUE-61_app-icons.md` §5 (design direction, master derivation, catalog population, verification), §7 (edge cases: alpha channel, sRGB, tinted desaturation, small-size legibility).
- `plans/SPEC.md` §9 (Liquid Glass design language), §10 Phase 9 (submission gate).
- `CLAUDE.md` — "Color is reserved for high-risk meds."

## Locked decisions inherited from the spec

- **No amber on the icon.** Amber (`LiquidGlassTheme.Colors.highRiskAccent`, the sole named color) is strictly reserved for the in-app high-risk press-and-hold ring. The icon is the app's resting face, not a moment of danger.
- **Monochromatic, one dominant shape.** No checklist/grid (that reads "list app"); no inscribed app name. A single glass-sheened pill capsule, or a minimal wrist silhouette with one pill, are the suggested marks.
- **Single-size catalog.** Xcode 26 declares only the 1024×1024 slot per platform; the OS derives display sizes at runtime. "Derivation" means producing the three *appearance* variants, not multiple pixel sizes.
- **No alpha channel; sRGB; tinted master fully desaturated** so the iOS tint overlay reads correctly.
- `Submission/assets/` holds the four canonical source masters; the catalog copies are byte-identical.

## Child issues

- [ ] **Issue: design review** — produce the four source PNGs (`AppIcon-1024-standard/dark/tinted/watch.png`) in `Submission/assets/`, post them to a #61 comment with a design rationale (how the mark honors SPEC §9), and get explicit reviewer sign-off **before** any catalog file is touched. No `Contents.json` edits in this child.
- [ ] **Issue: catalog population + validation** — take the signed-off masters, copy them byte-identically into both `AppIcon.appiconset` directories, add the `filename` keys to both `Contents.json` files, and verify `xcodebuild` asset validation passes clean on both schemes with on-device (simulator) checks of all four appearances.

## Acceptance for the epic

- All four masters present in `Submission/assets/`, each with no alpha channel (`sips -g hasAlpha` returns `NO`) and sRGB profile.
- Both schemes build with **no asset-catalog warnings or errors**.
- iPhone home screen shows the standard variant (light), the dark variant in dark mode, and the tinted variant reads cleanly under the OS tint overlay (no residual hue); the watch app grid renders the mark legibly at native scale.
- PR(s) include home-screen (iPhone) + app-grid (watch) screenshots showing the icon, plus the design rationale sign-off.
- `pre-commit run --all-files` clean; existing tests still pass (pure asset change, no Swift).

## Out of scope (for this epic)

- Animated icons (unsupported at v1 on both platforms).
- App Store marketing artwork beyond the icon (that is #62).
- watchOS complication images (separate WidgetKit assets, Phase 7).
- App Store Connect 1024 listing upload (the standard master serves double duty; confirmed during submission prep, not here).

---

## Sequencing notes

- Parent of this epic in the phase hierarchy is **#10** (Phase 9 — Hardening & Submission).
- **#61 must merge before #62** (screenshots need the real icon on the home screen / grid) and therefore before **#66** (soak uses the shipped icon).
- The two children are sequential: design review (sign-off) gates catalog population, which avoids burning a CI round-trip on purely visual feedback.
