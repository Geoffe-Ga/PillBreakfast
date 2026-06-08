# SPEC — Issue #62: Screenshots & Marketing Copy

| Field | Value |
|---|---|
| Issue | #62 |
| Phase | 9 — Hardening & Submission Prep |
| Labels | `spec-decomposition`, `polish`, `phase-9-hardening` |
| Status | Draft |
| Date | 2026-06-07 |
| Parent epic | #10 |
| Related issues | #61 (icon must be in place before screenshots are captured), #66 (soak diary may surface copy corrections) |

---

## 1. Summary

Produce the complete App Store Connect submission package for the non-binary portions of the v1
listing: (a) the screenshot set for both iOS and watchOS at all required device sizes, (b) the
marketing copy deck (app name, subtitle, promotional text, full description, keywords), and (c) a
final audit that confirms the privacy nutrition label in `Submission/privacy-nutrition.md` is
accurate and current. No code changes are made by this issue.

---

## 2. Problem Statement / Motivation

`Submission/screenshot-script.md` is a placeholder stub. `Submission/marketing-copy.md` does not
yet exist. App Store Connect will not accept a submission without screenshots at the required device
sizes, and incomplete or inaccurate marketing copy risks review rejection or, worse, App Store
positioning that misrepresents the product thesis. This work must complete before the Phase 9 gate
can be declared done ("Submit to TestFlight; one week of dogfooding with no critical bugs").

Screenshots must use anonymized data. The issue brief explicitly requires replacing real medication
names with stand-ins like "Med A" — the App Store does not need Geoff's prescription list.

---

## 3. Goals & Non-Goals

**Goals:**
- Screenshots at all required App Store Connect device sizes for iPhone and Apple Watch
- Each screenshot shows a specific named surface from the app (see shot-list in §5.1)
- All screenshots use anonymized medication names and dosages
- `Submission/marketing-copy.md` populated with final, production-ready copy
- Privacy nutrition label reviewed and confirmed accurate against the shipped codebase
- HealthKit usage description language in `Info.plist` is consistent with the privacy label

**Non-Goals:**
- App Preview videos (Apple allows up to 3 preview videos per device size; these are a v1.1 item)
- iPad screenshots (PillBreakfast targets iPhone + Apple Watch, not iPad)
- Localized copy for any locale other than English (US) at v1
- Marketing artwork beyond screenshots (App Store Connect no longer requires separate promo art
  for most placements)
- Writing new code to support screenshot capture (all surfaces must already exist from Phases 1–8)

---

## 4. Background & Current State

### Existing submission artifacts

- `Submission/privacy-nutrition.md` — fully drafted, covers all App Store Connect privacy
  questionnaire categories. The HealthKit read-only constraint (SPEC §3.2, CLAUDE.md) is correctly
  reflected: `NSHealthUpdateUsageDescription` is absent (intentional, read-only import only);
  `NSHealthShareUsageDescription` is present on the iOS target.
- `Submission/screenshot-script.md` — stub, no content.
- `Submission/asset-checklist.md` — stub, no content.
- `Submission/soak-diary-TEMPLATE.md` — stub; the actual diary is produced by #66.

### App surfaces available for screenshots

Phase 1–8 shipped the following screens that correspond directly to the SPEC §2 north-star journeys:

**watchOS:**
- `RightNowView` — pending queue root; shows "N pills pending" or "All caught up"
- `MarkTakenView` — single-pill tap-through card (medication name, dosage, Confirm button)
- `HighRiskConfirmButton` — press-and-hold ring visible mid-hold (requires gesture capture)
- `MealCompletionView` / `QueueSuccessView` — "All caught up" glass shimmer success state
- `PRNListView` — PRN section with ingredient-aware running totals per row
- `PRNQuantityPickerView` — quantity picker before confirm
- `SafetyWarningView` — soft warning interstitial when a ceiling/interval would be exceeded
- `SnoozeView` — time picker with Liquid Glass styling

**iOS:**
- `MainTabView` (3 tabs: Regimen, History, Settings)
- `RegimenListView` — medication list grouped by Maintenance / As-Needed
- `EditMedicationView` / `MedicationFormView` — add/edit form
- `HistoryTabView` — calendar heatmap
- `DayDrillDownView` — per-day dose log
- `PDFExporter` output rendered in share sheet

### App Store Connect screenshot requirements (2025–2026)

App Store Connect requires at minimum one screenshot per supported device type. Optional additional
screenshots (up to 10 per device type) improve conversion. Required device types for PillBreakfast:

| Platform | Required device size | Display resolution | Notes |
|---|---|---|---|
| iPhone | 6.9" display (iPhone 16 Pro Max / 17 Pro Max class) | 1320×2868 @3x | Required for iPhone-only apps |
| iPhone | 6.7" display (iPhone 16 Plus class) | 1290×2796 @3x | Required if you want separate copy per size |
| Apple Watch | Series 7–10 / 11 (45mm or 46mm) | 396×484 @2x | Required for watchOS apps |

Apple requires at least one set at the 6.9" size. If a single size set is provided, App Store
Connect scales it for all smaller iPhones. The 6.7" set is optional but recommended to avoid
cropping artifacts on Plus-class devices.

The simulator in CLAUDE.md (`iPhone 17`, `Apple Watch Series 11 46mm`) maps to the 6.9" and
watchOS large-case sizes respectively, which is the correct pairing for the primary screenshot set.

---

## 5. Detailed Design / Plan

### 5.1 Screenshot shot-list

Each screenshot has a number (ordering in the App Store gallery), a platform, a surface name, what
data is loaded, the caption that appears below the screenshot in App Store Connect, and any capture
notes. All medication names in screenshots use the anonymized stand-ins defined in §5.3.

**Capture environment:** iPhone 17 simulator at default scale, watchOS 26 simulator on Apple Watch
Series 11 (46mm), both running a Debug build seeded with the anonymized regimen defined in §5.3.
Status bar clock set to 9:41 AM (App Store convention). Dark mode preferred for watchOS (Liquid
Glass reads best on the dark watch face). Light mode preferred for iPhone screenshots (default
system appearance).

---

#### Watch screenshots (5 recommended; 3 minimum)

**W-1: Pending queue — single pill card (MarkTakenView)**

Surface: `MarkTakenView` showing the first pending dose.
Data: "Med A · 300 mg · 1 tablet" — this is the high-risk maintenance med stand-in.
State: standard Confirm button (not mid-hold), so the full card layout is visible.
Caption text (appears in App Store below screenshot): "One pill per screen. No list, no clutter."
Capture note: verify the medication name uses `LiquidGlassTheme.Typography.medicationNameFont`
(SF Pro Rounded) and dosage uses `dosageFont` (monospaced digits). Both should be visually distinct.

**W-2: Press-and-hold in progress (HighRiskConfirmButton mid-hold)**

Surface: `MarkTakenView` with `HighRiskConfirmButton` at approximately 60–70% hold completion
(progress ring filled to about 2 o'clock position).
Data: same "Med A · 300 mg" card.
State: ring visible; button label should read the in-progress state.
Caption text: "Safety-critical doses require a hold. No accidental logs."
Capture note: this screenshot must be captured via `XCUITest` screenshot during a long-press
gesture, or by using the simulator's slow-motion animation mode. Do not fabricate the state in a
SwiftUI Preview — use the live app.

**W-3: All caught up success state (QueueSuccessView)**

Surface: `QueueSuccessView` (or `MealCompletionView`) showing the glass shimmer success state.
Data: "All morning pills logged" or equivalent completion text; timestamp shown.
Caption text: "Done. Every morning in three taps."
Capture note: trigger by logging all pending doses in the anonymized regimen session.

**W-4: PRN section with ingredient totals (PRNListView)**

Surface: `PRNListView` showing two or three anonymized PRN medications with running totals.
Data: "Med C · 600 mg gabapentin-class today · last 11:42 AM" and "Med D · 1500 mg of daily limit"
(or similar stand-in phrasing that reflects the actual UI text format from `PRNRowView`).
Caption text: "Know exactly what you've taken, down to the ingredient."
Capture note: seed one PRN log entry earlier in the session before capturing.

**W-5: Safety warning interstitial (SafetyWarningView)**

Surface: `SafetyWarningView` showing the soft ceiling/interval warning.
Data: Warning mentioning "Ingredient B · 3500 mg today · ceiling 4000 mg" or equivalent.
Caption text: "Ingredient-aware safety checks protect you even across different products."
Capture note: trigger by attempting to log a PRN dose that would exceed the seeded ceiling.

---

#### iPhone screenshots (4 recommended; 2 minimum)

**I-1: Regimen list (RegimenListView)**

Surface: `RegimenListView` with maintenance and as-needed sections visible.
Data: 3 maintenance meds (Med A, Med B, Med C) and 2 PRN meds (Med D, Med E).
Caption text: "Set it once on your iPhone. Log everything from your wrist."
Capture note: scroll position should show both section headers. Verify the "Add Medication" button
is visible in the navigation bar or toolbar.

**I-2: History calendar heatmap (HistoryTabView)**

Surface: `HistoryTabView` showing the 30-day heatmap with some days filled and some empty.
Data: 5 days of logged history (anonymized), varying density to show the heatmap gradient.
Caption text: "30 days of history at a glance. Export a PDF for your next appointment."
Capture note: the current month view centered; at least 3 distinct heatmap intensity levels visible.

**I-3: Day drill-down (DayDrillDownView)**

Surface: `DayDrillDownView` for one day showing timestamped dose entries.
Data: 4 morning maintenance entries at 8:04–8:07 AM, 1 PRN entry at 2:15 PM.
Caption text: "Every dose, timestamped. Ready for your psychiatrist."
Capture note: status icons (taken/skipped) should be visible. Running daily totals for PRN
ingredients visible at the bottom of the list.

**I-4: PDF export in share sheet**

Surface: iOS share sheet overlaid on the PDF preview.
Data: Same anonymized data; PDF shows the 5 seeded days.
Caption text: "Export 30 days as a PDF. One tap, one share."
Capture note: trigger via the "Export" button in the History tab. Capture the standard iOS share
sheet. The `UIActivityViewController` sheet must be fully expanded and visible, not mid-animation.

---

### 5.2 Anonymized regimen seed

The following regimen is used exclusively for screenshot capture. It must be seeded into a fresh
simulator state (wipe + reinstall) before capturing to avoid any real data appearing.

| Stand-in name | Real-regimen class | Display name in app | Schedule / kind | Dosage shown |
|---|---|---|---|---|
| Med A | Lithium-class maintenance (high-risk) | Med A | Maintenance, daily 8:00 AM | 300 mg · 1 tablet |
| Med B | Generic maintenance supplement | Med B | Maintenance, daily 8:00 AM | 1000 IU · 1 capsule |
| Med C | Generic maintenance supplement | Med C | Maintenance, daily 8:00 AM | 500 mg · 1 tablet |
| Med D | Gabapentin-class PRN | Med D | PRN, ceiling 1200 mg/day | 300 mg/capsule |
| Med E | Acetaminophen-class PRN | Med E | PRN, ceiling 4000 mg/day | 500 mg/tablet |

Ingredient stand-ins for the safety warning screenshot:
- "Ingredient A" maps to Med A's active ingredient (isHighRisk: true)
- "Ingredient B" maps to Med E's active ingredient (ceiling 4000 mg)

This seed data must not include Geoff's name, any real diagnosis, or any identifying information.

### 5.3 Capture procedure

1. Build a debug IPA on iPhone 17 simulator and watchOS simulator (paired).
2. Wipe simulator state: Device > Erase All Content and Settings.
3. Install fresh build; complete onboarding skipping HealthKit (tap "Add manually").
4. Seed the anonymized regimen via the Regimen tab (manual entry).
5. Seed 5 days of history by backdating entries via the debug menu (if available) or by setting
   the system clock back day-by-day.
6. Capture each screenshot in order W-1 through W-5, I-1 through I-4.
7. Export at full resolution using the simulator's "Save Screenshot" (Cmd+S in Simulator.app) or
   `xcrun simctl io booted screenshot <output.png>`.
8. Filename convention: `W-1_pending-queue.png`, `I-1_regimen-list.png`, etc.

For W-2 (mid-hold capture), use `xcrun simctl io booted screenshot` triggered during a UITest
that performs a long-press gesture — screenshot the state at the 60% progress point.

---

### 5.4 Marketing copy deck

The copy below is a deliverable: it should be written into `Submission/marketing-copy.md` verbatim
with section headers as shown. This is the source of truth the App Store Connect uploader reads from.

---

**BEGIN MARKETING COPY DELIVERABLE**

```
# PillBreakfast — App Store Marketing Copy
# Version: v1 submission
# Date: 2026-06-07
# Locale: en-US

## App Name
PillBreakfast

## Subtitle (30 characters max)
Watch-first med tracker

## Promotional Text (170 characters max — editable without a new build submission)
Tap through your morning regimen on your wrist. One pill per screen, one tap to confirm. Safety
checks built in.

## Description (4000 characters max)
PillBreakfast turns a daily pill regimen into a tap-through ritual on your Apple Watch.

Open the app — or tap a notification — and your morning medications appear one per screen. Tap to
confirm each one. Done. The watch handles logging; the iPhone handles setup and history review.

ZERO-AMBIGUITY LOGGING ON YOUR WRIST
Every medication gets its own full-screen card. No list, no checkbox grid, no hunting. One pill,
one tap, move on.

SAFETY-CRITICAL DOSES REQUIRE A HOLD
Mark any medication high-risk and it requires a press-and-hold to log. A glass progress ring fills
as you hold — release early and nothing is recorded. No accidental double-logs.

INGREDIENT-AWARE SAFETY CHECKS
For as-needed medications, PillBreakfast tracks running totals per active ingredient — not just
per product. Take a combination pain reliever after standalone acetaminophen, and the app will
warn you about the shared ingredient total before you confirm. Soft warning, not a hard block —
you can always override.

LOG FROM YOUR WRIST, REVIEW ON YOUR PHONE
The iPhone app is deliberately minimal: define your regimen once, review your history, export a
PDF for your next appointment. No "take pills now" prompts on the phone — that's the watch's job.

WORKS WITHOUT YOUR PHONE
Reminders are scheduled directly on the watch, so they fire even when your iPhone is off or out of
range.

LIQUID GLASS DESIGN
Built for watchOS 26 and iOS 26. Every surface uses Apple's Liquid Glass material — translucent,
refined, and at home on your wrist.

PRIVACY BY DESIGN
No account. No server. No third-party analytics. Your medications stay on your devices.

IMPORT FROM APPLE HEALTH (OPTIONAL)
If you already have medications in Apple Health, PillBreakfast can import them during setup —
saving you from retyping every medication name. PillBreakfast reads from Health; it never writes
back.

## Keywords (100 characters max, comma-separated)
medication tracker,pill reminder,lithium,watch,dose log,schedule,PRN,health,prescription,daily

## What's New (v1.0)
First release. Tap-through logging on Apple Watch, ingredient-aware PRN safety checks, snooze-
until-time, PDF export for doctor appointments. Built for watchOS 26 and iOS 26.

## Support URL
https://github.com/Geoffe-Ga/PillBreakfast

## Marketing URL (optional)
(leave blank for v1)

## Privacy Policy URL
(required — point to a GitHub-hosted plain-text privacy policy or the README privacy section)
```

**END MARKETING COPY DELIVERABLE**

---

### 5.5 Privacy nutrition label review

`Submission/privacy-nutrition.md` is the authoritative source. Before closing #62, the implementer
must do a line-by-line audit against the current codebase state:

1. Confirm `NSHealthUpdateUsageDescription` is absent from `PillBreakfast/Info.plist` (read-only
   import constraint — SPEC §3.2, CLAUDE.md). If it is somehow present, that is a bug in the iOS
   target's capabilities setup.

2. Confirm `NSHealthShareUsageDescription` is present in `PillBreakfast/Info.plist` with language
   consistent with read-only import. Suggested text: "PillBreakfast can import your medications
   from Apple Health to speed up setup. It reads medication names and schedules; it does not write
   to Apple Health."

3. Confirm no third-party SDK is linked that would change the Diagnostics or Identifiers rows. The
   current ADR (`plans/decisions/2026-05-29_crash-reporting.md`) uses MetricKit-only, which keeps
   Diagnostics → Crash Data as "Not Collected." If sentry-cocoa has been added since that ADR,
   the nutrition label needs revision before submission.

4. Confirm App Store Connect "Tracking" is answered "No" — no IDFA, no ATT prompt, no
   cross-app tracking. PillBreakfast has no advertising dependency.

The PR body for #62 must include an explicit "Anonymization audit" section listing:
- Every medication name that appears in any screenshot and confirming it is a stand-in
- The `NSHealthShareUsageDescription` string as it appears in the Info.plist
- Confirmation that no third-party SDK has been added since the MetricKit ADR

---

## 6. Assets & Deliverables

| Path | Description |
|---|---|
| `Submission/screenshots/W-1_pending-queue.png` | Watch: MarkTakenView, single pill card |
| `Submission/screenshots/W-2_high-risk-hold.png` | Watch: HighRiskConfirmButton mid-hold |
| `Submission/screenshots/W-3_success-state.png` | Watch: QueueSuccessView glass shimmer |
| `Submission/screenshots/W-4_prn-list.png` | Watch: PRNListView with ingredient totals |
| `Submission/screenshots/W-5_safety-warning.png` | Watch: SafetyWarningView interstitial |
| `Submission/screenshots/I-1_regimen-list.png` | iPhone: RegimenListView |
| `Submission/screenshots/I-2_history-heatmap.png` | iPhone: HistoryTabView calendar |
| `Submission/screenshots/I-3_day-drilldown.png` | iPhone: DayDrillDownView |
| `Submission/screenshots/I-4_pdf-share-sheet.png` | iPhone: PDF export + share sheet |
| `Submission/marketing-copy.md` | Full copy deck (§5.4 content) |
| `Submission/screenshot-script.md` | Step-by-step capture instructions (the §5.3 procedure, written as the runbook) |

The `Submission/privacy-nutrition.md` file already exists. This issue reviews it; it is not
replaced unless corrections are needed.

---

## 7. Edge Cases & Failure Modes

**Screenshot cropping on 6.7" devices.** If only 6.9" screenshots are submitted, App Store Connect
will auto-scale them for 6.7" iPhones. The scaling is approximately 97% — usually imperceptible.
If the crop line hits the status bar or an important UI element, produce a separate 6.7" set
(`iPhone 16 Plus` simulator). This is optional for v1 but flag it in the PR if any screenshot
looks clipped.

**Watch screenshot resolution.** `xcrun simctl io` exports at the simulator's logical resolution.
For the 46mm watch simulator, this is 396×484 points at @2x (792×968 pixels). App Store Connect
currently accepts watch screenshots at this resolution. Verify the upload succeeds; if the uploader
rejects the resolution, check Apple's current App Store Connect help page for the accepted sizes.

**Mid-hold screenshot requires test harness.** W-2 cannot be captured by a human hold on a
simulator. Use `XCUITest` + `app.screenshot()` called after a gesture that pauses at mid-progress,
or programmatically inject a preview mode that shows the ring at a fixed progress value. Do not
fake it in a SwiftUI Preview (the App Store review team has rejected screenshot sets that do not
match the actual app UI).

**Status bar artifacts.** The simulator status bar shows real time unless overridden. Use
`xcrun simctl status_bar booted override --time '9:41'` before capturing to set the conventional
App Store time.

**Copy character limits.** Subtitle (30 chars), promotional text (170 chars), keywords (100 chars).
Run `wc -c` or count manually before finalizing. The description (4000 char) and "What's New"
(4000 char) are generous — the v1 text above is well within limits.

**HealthKit import screenshot.** The shot-list above does not include a screenshot of the HealthKit
import flow because it requires an iPhone with a HealthKit-capable simulator (iOS 26 simulator, but
Health app data is not populated by default in a fresh sim). If marketing value justifies it in a
future update, it can be added as screenshot I-5. Omitting it for v1 is the correct call.

---

## 8. Verification / Acceptance Criteria

**Screenshots:**
- [ ] Nine screenshot files are present in `Submission/screenshots/` with the naming convention above
- [ ] All watch screenshots are 396×484pt @2x (or the current App Store Connect accepted size)
- [ ] All iPhone screenshots are captured on iPhone 17 simulator at full resolution
- [ ] No real medication names, diagnoses, or personally identifying information appears in any screenshot
- [ ] Status bar shows 9:41 AM in all screenshots
- [ ] W-2 (mid-hold) shows the press-and-hold ring at a visually obvious mid-progress state (30–70% fill)
- [ ] PR body includes an anonymization audit confirming every med name is a stand-in

**Marketing copy:**
- [ ] `Submission/marketing-copy.md` created and populated with all fields from §5.4
- [ ] Subtitle ≤ 30 characters
- [ ] Promotional text ≤ 170 characters
- [ ] Keywords ≤ 100 characters
- [ ] Description ≤ 4000 characters
- [ ] Copy does not claim PillBreakfast writes to Apple Health (it does not — read-only import only)
- [ ] Copy does not suggest logging from iPhone (CLAUDE.md hard rule: iPhone is setup+review only)

**Privacy nutrition label:**
- [ ] `NSHealthUpdateUsageDescription` is absent from `PillBreakfast/Info.plist`
- [ ] `NSHealthShareUsageDescription` is present with language reflecting read-only import
- [ ] `Submission/privacy-nutrition.md` Diagnostics row is accurate (MetricKit-only = "Not Collected")
- [ ] No third-party SDK linked that was not present when `privacy-nutrition.md` was last audited

**Process:**
- [ ] `pre-commit run --all-files` is clean
- [ ] All existing tests pass (no code change; pure asset + content PR)
- [ ] PR opened with `Refs #10` and `Closes #62`

---

## 9. Risks & Open Questions

**Risk: mid-hold screenshot technique.** Getting a clean W-2 screenshot at the right progress
point requires either UITest automation or a preview shim. The UITest approach is preferred (it
tests the real code path). If the progress ring is driven by a continuous gesture recognizer and
UITest cannot pause mid-gesture, a SwiftUI Preview with `previewLayout` and a fixed progress value
is an acceptable fallback, provided the capture is clearly labeled "Preview-based" in the PR and a
note is filed to replace it with a live capture in v1.1.

**Risk: description copy.** The description above is drafted from SPEC §1–2. It should be reviewed
by Geoff before upload to App Store Connect — the PR review is the natural gate for this.

**Open question: privacy policy URL.** The App Store requires a privacy policy URL. Options:
(a) a GitHub-hosted Markdown file in the repo, (b) a static page on creekmasons.com, or (c) a link
to the README's privacy section. This must be resolved before submission. The marketing copy
template above marks it as TBD.

**Open question: support URL.** Currently pointing to the GitHub repo. If Geoff prefers a different
support contact (email, landing page), update before submission.

**Open question: App Clip.** Not in scope for v1. No App Clip screenshots needed.

---

## 10. Decomposition Hints

If this issue is split for parallel work:

1. Child A: Regimen seed + watch screenshots (W-1 through W-5) — watch-side UI expertise
2. Child B: iPhone screenshots (I-1 through I-4) + marketing copy — iPhone UI + copywriting
3. Child C: Privacy nutrition label audit — can run in parallel with A and B; blocks the submission
   checklist but not the screenshot capture

All three children need the anonymized regimen seed (§5.2) defined before work begins.

---

## 11. References

- SPEC §1 — Vision (product thesis; informs description tone)
- SPEC §2 — North-star journeys (each screenshot maps to a journey)
- SPEC §3.2 — HealthKit read-only constraint (informs description and privacy label)
- SPEC §6 — iPhone companion (setup+review only — enforces the "no logging on phone" copy rule)
- SPEC §7 — watchOS app (tap-through queue, PRN section, safety warning surfaces)
- SPEC §9 — Liquid Glass design language
- SPEC §10 Phase 9 — submission prep gate
- CLAUDE.md — "Watch never gets logging UI on the iPhone" hard rule
- `Submission/privacy-nutrition.md` — current privacy label source of truth
- `PillBreakfast/Info.plist` — `NSHealthShareUsageDescription` location
- Apple HIG — [App Store screenshots](https://developer.apple.com/design/human-interface-guidelines/screenshots)
- Apple App Store Connect Help — Screenshot specifications (current device size chart)
- Issue #61 — icon must be merged before screenshots are captured
