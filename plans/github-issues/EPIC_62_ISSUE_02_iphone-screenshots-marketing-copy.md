## Role

You are an iPhone UI engineer and copywriter producing the four iPhone App Store screenshots for PillBreakfast v1 and the full marketing copy deck. You hold the product thesis firmly: watch-first logging, iPhone is setup+review only, HealthKit is read-only import.

## Goal

Capture the four iPhone screenshots (I-1…I-4) on the iPhone 17 simulator using the shared §5.2 anonymized regimen, and write `Submission/marketing-copy.md` verbatim from §5.4 — staying within every App Store character limit and honoring the two hard copy rules: no claim that PillBreakfast writes to Apple Health, and no implication that logging happens on the iPhone.

## Context

- **Parent epic:** #62.
- **Predecessors:** #61 (icon merged — visible behind the iPhone captures); the watch-screenshots child (#62 child 1) **defines the §5.2 seed** this child consumes (build on the same anonymized regimen).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-62_screenshots-marketing-copy.md` §4 (iPhone surfaces), §5.1 iPhone shot-list (I-1…I-4 with captions), §5.2 (seed), §5.4 (the verbatim marketing copy deliverable), §7 (6.7" cropping, copy character limits, status-bar edge cases), §8 (acceptance — marketing-copy block), §9 (description-review risk; privacy-policy / support-URL open questions).
- **Files involved:**
  - `Submission/screenshots/I-1_regimen-list.png` (new) — `RegimenListView`, maintenance + as-needed sections.
  - `Submission/screenshots/I-2_history-heatmap.png` (new) — `HistoryTabView` 30-day heatmap, ≥3 intensity levels.
  - `Submission/screenshots/I-3_day-drilldown.png` (new) — `DayDrillDownView`, timestamped entries + PRN totals.
  - `Submission/screenshots/I-4_pdf-share-sheet.png` (new) — `UIActivityViewController` share sheet over the PDF preview, fully expanded.
  - `Submission/marketing-copy.md` (new) — the full §5.4 deck (name, subtitle, promo, description, keywords, what's new, URLs).
- **Prior decisions (locked):**
  - **Copy rule 1 — no Health-write claim.** The Apple Health line must say PillBreakfast *reads* from Health and *never writes back* (read-only import). This mirrors the privacy label (`NSHealthUpdateUsageDescription` absent).
  - **Copy rule 2 — no iPhone-logging.** The description keeps the phone to setup / history / PDF export; no "quick log" or "take pills now" language (CLAUDE.md hard rule).
  - Character limits: subtitle ≤30, promotional text ≤170, keywords ≤100, description ≤4000. Count before finalizing.
  - 9:41 status bar (`xcrun simctl status_bar booted override --time '9:41'`); light mode preferred for iPhone; anonymized data only.
  - Privacy-policy URL and support URL are open questions — leave the §5.4 placeholders/TBD and flag in the PR for Geoff to resolve before upload.

## Output Format

A single PR containing:

- [ ] Four iPhone PNGs in `Submission/screenshots/` with the `I-N_*` naming, all anonymized, 9:41 status bar, full resolution; I-4's share sheet fully expanded (not mid-animation).
- [ ] `Submission/marketing-copy.md` written verbatim per §5.4, with the section headers shown, every field populated, and every character limit satisfied.
- [ ] PR body lists the per-character counts for subtitle / promo / keywords (proving they pass) and the per-shot caption text from §5.1.
- [ ] PR body flags the open privacy-policy URL and support URL for Geoff's decision; the description copy is called out for his review before App Store upload.

## Examples

The copy fields and their limits this child must satisfy (SPEC §5.4 / §8):

```
## Subtitle (30 characters max)
Watch-first med tracker

## Promotional Text (170 characters max)
Tap through your morning regimen on your wrist. One pill per screen, one tap to confirm. Safety checks built in.

## Keywords (100 characters max, comma-separated)
medication tracker,pill reminder,lithium,watch,dose log,schedule,PRN,health,prescription,daily
```

The read-only-Health description line (must not be reworded into a write claim):

```
IMPORT FROM APPLE HEALTH (OPTIONAL)
... PillBreakfast reads from Health; it never writes back.
```

## Constraints

**Scope fence:** iPhone screenshots + the marketing copy deck only. **No** watch screenshots and **no** owning of the §5.2 seed (that is child 1 — consume it). **No** privacy-label edits (child 3 audits it). **No new code to support capture** — all iPhone surfaces already exist from Phases 1–8.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Captures come from the live iPhone app on the simulator — no code change; this child adds only PNGs and one Markdown copy deck. The app remains demoable throughout.

## Done-Done

- [ ] Existing tests pass (pure asset + content change; no Swift).
- [ ] Four iPhone PNGs present, anonymized, 9:41 status bar, full res; I-4 share sheet fully expanded.
- [ ] `Submission/marketing-copy.md` complete; subtitle ≤30, promo ≤170, keywords ≤100, description ≤4000; no Health-write claim; no iPhone-logging implication.
- [ ] `pre-commit run --all-files` is clean (PNG + Markdown included).
- [ ] PR opened with `Closes #<this issue>` and `Refs #62`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`, `docs`
