# Filing Plan — PillBreakfast Spec Decomposition

> Runbook for the parent agent. Do **not** execute this until the user has reviewed the decomposition. Step 8 of the spec-decomposition skill is irreversible enough that a pre-flight check is non-negotiable.

## Pre-flight

```bash
# Confirm you are in the right repo
cd /Users/geoffgallinger/Projects/PillBreakfast
gh repo view --json nameWithOwner -q .nameWithOwner

# Confirm the decomposition files exist
ls plans/git-issues/EPIC_*.md | wc -l    # expect 72 (1 SPEC summary + 11 epic bodies + 61 child issues — but wc on `EPIC_*` excludes the SPEC summary, so expect 72)
ls plans/git-issues/EPIC_*_ISSUE_*.md | wc -l  # expect 61
ls plans/git-issues/EPIC_*[a-z].md | grep -v ISSUE | wc -l  # expect 11

# Dry run: skim one epic body and one child body
cat plans/git-issues/EPIC_01_skeleton.md
cat plans/git-issues/EPIC_01_ISSUE_01_skeleton.md
```

## Step 1 — Labels

Create only the labels that do not already exist. The skill recommends a small, navigable set.

```bash
# Cross-cutting
gh label create "epic" --description "Tracks a workstream from a SPEC" --color "5319e7"
gh label create "spec-decomposition" --description "Issue filed from a SPEC decomposition" --color "0e8a16"
gh label create "tracer-code" --description "Sequenced per tracer-code methodology" --color "1d76db"
gh label create "tracer-skeleton" --description "Wires the skeleton for an epic" --color "c2e0c6"
gh label create "core" --description "Replaces a stub with real logic" --color "fbca04"
gh label create "edges" --description "Validation, edge cases, error paths" --color "fef2c0"
gh label create "polish" --description "Logging, metrics, docs, UX niceties" --color "d4c5f9"
gh label create "future-work" --description "Out of scope for v1; parked" --color "bfdadc"
gh label create "needs-spec" --description "Under-specified; do not pick up until groomed" --color "e99695"

# Domain
gh label create "design-system" --description "Liquid Glass / shared design tokens" --color "6b6cff"
gh label create "notifications" --description "UserNotifications and related" --color "0052cc"
gh label create "concurrency" --description "Swift 6 strict concurrency / actor isolation" --color "5319e7"
gh label create "tests" --description "Test infrastructure / coverage" --color "0e8a16"
gh label create "docs" --description "Documentation changes" --color "c5def5"
gh label create "a11y" --description "Accessibility / VoiceOver" --color "fcd34d"
gh label create "v2" --description "Deliberately deferred to v2" --color "bfd4f2"
gh label create "advocacy" --description "External advocacy task (e.g. Apple Feedback)" --color "fef2c0"

# Phase-tagging (for backlog navigability)
gh label create "phase-0-skeleton" --color "ededed"
gh label create "phase-1-data-model" --color "ededed"
gh label create "phase-2-maintenance" --color "ededed"
gh label create "phase-3-high-risk" --color "ededed"
gh label create "phase-4-prn-safety" --color "ededed"
gh label create "phase-5-snooze" --color "ededed"
gh label create "phase-6-healthkit" --color "ededed"
gh label create "phase-7-widgets" --color "ededed"
gh label create "phase-8-history-export" --color "ededed"
gh label create "phase-9-hardening" --color "ededed"
```

If any of these already exist, `gh label create` errors out — that's fine; the rest still proceed.

## Step 2 — File the 11 epics first, capture numbers

```bash
EPIC_01_NUMBER=$(gh issue create \
  --title "epic: Phase 0 - Paired iOS + watchOS Skeleton" \
  --body-file plans/git-issues/EPIC_01_skeleton.md \
  --label "epic,spec-decomposition,phase-0-skeleton,tracer-code" \
  --json number --jq .number)
echo "EPIC_01 = $EPIC_01_NUMBER"

EPIC_02_NUMBER=$(gh issue create \
  --title "epic: Phase 1 - Data Model & WatchConnectivity Sync Tracer" \
  --body-file plans/git-issues/EPIC_02_data-model-and-wc-sync.md \
  --label "epic,spec-decomposition,phase-1-data-model,tracer-code" \
  --json number --jq .number)
echo "EPIC_02 = $EPIC_02_NUMBER"

EPIC_03_NUMBER=$(gh issue create \
  --title "epic: Phase 2 - Maintenance Flow End-to-End" \
  --body-file plans/git-issues/EPIC_03_maintenance-flow.md \
  --label "epic,spec-decomposition,phase-2-maintenance,tracer-code" \
  --json number --jq .number)
echo "EPIC_03 = $EPIC_03_NUMBER"

EPIC_04_NUMBER=$(gh issue create \
  --title "epic: Phase 3 - High-Risk Confirmation + Liquid Glass First Pass" \
  --body-file plans/git-issues/EPIC_04_high-risk-and-liquid-glass.md \
  --label "epic,spec-decomposition,phase-3-high-risk,design-system,tracer-code" \
  --json number --jq .number)
echo "EPIC_04 = $EPIC_04_NUMBER"

EPIC_05_NUMBER=$(gh issue create \
  --title "epic: Phase 4 - PRN Flow + Ingredient-Aware Running Totals" \
  --body-file plans/git-issues/EPIC_05_prn-and-ingredient-safety.md \
  --label "epic,spec-decomposition,phase-4-prn-safety,tracer-code" \
  --json number --jq .number)
echo "EPIC_05 = $EPIC_05_NUMBER"

EPIC_06_NUMBER=$(gh issue create \
  --title "epic: Phase 5 - Snooze-Until-Time" \
  --body-file plans/git-issues/EPIC_06_snooze-until-time.md \
  --label "epic,spec-decomposition,phase-5-snooze,tracer-code" \
  --json number --jq .number)
echo "EPIC_06 = $EPIC_06_NUMBER"

EPIC_07_NUMBER=$(gh issue create \
  --title "epic: Phase 6 - HealthKit One-Tap Onboarding Import" \
  --body-file plans/git-issues/EPIC_07_healthkit-import.md \
  --label "epic,spec-decomposition,phase-6-healthkit,tracer-code" \
  --json number --jq .number)
echo "EPIC_07 = $EPIC_07_NUMBER"

EPIC_08_NUMBER=$(gh issue create \
  --title "epic: Phase 7 - Widgets & Complication" \
  --body-file plans/git-issues/EPIC_08_widgets-and-complication.md \
  --label "epic,spec-decomposition,phase-7-widgets,tracer-code" \
  --json number --jq .number)
echo "EPIC_08 = $EPIC_08_NUMBER"

EPIC_09_NUMBER=$(gh issue create \
  --title "epic: Phase 8 - History, PDF Export, and Polish" \
  --body-file plans/git-issues/EPIC_09_history-export-polish.md \
  --label "epic,spec-decomposition,phase-8-history-export,tracer-code" \
  --json number --jq .number)
echo "EPIC_09 = $EPIC_09_NUMBER"

EPIC_10_NUMBER=$(gh issue create \
  --title "epic: Phase 9 - Hardening & TestFlight Submission" \
  --body-file plans/git-issues/EPIC_10_hardening-and-submission.md \
  --label "epic,spec-decomposition,phase-9-hardening,tracer-code" \
  --json number --jq .number)
echo "EPIC_10 = $EPIC_10_NUMBER"

EPIC_11_NUMBER=$(gh issue create \
  --title "epic: Future Work Placeholders (SPEC §12)" \
  --body-file plans/git-issues/EPIC_11_future-work-placeholders.md \
  --label "epic,spec-decomposition,future-work,needs-spec" \
  --json number --jq .number)
echo "EPIC_11 = $EPIC_11_NUMBER"
```

## Step 3 — Substitute real epic numbers into child bodies

```bash
# Use BSD sed (macOS default) syntax. -i '' is required for in-place edit.
SED_IN_PLACE() { sed -i '' "$@"; }

SED_IN_PLACE "s/#EPIC_01_NUMBER/#${EPIC_01_NUMBER}/g" plans/git-issues/EPIC_01_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_02_NUMBER/#${EPIC_02_NUMBER}/g" plans/git-issues/EPIC_02_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_03_NUMBER/#${EPIC_03_NUMBER}/g" plans/git-issues/EPIC_03_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_04_NUMBER/#${EPIC_04_NUMBER}/g" plans/git-issues/EPIC_04_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_05_NUMBER/#${EPIC_05_NUMBER}/g" plans/git-issues/EPIC_05_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_06_NUMBER/#${EPIC_06_NUMBER}/g" plans/git-issues/EPIC_06_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_07_NUMBER/#${EPIC_07_NUMBER}/g" plans/git-issues/EPIC_07_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_08_NUMBER/#${EPIC_08_NUMBER}/g" plans/git-issues/EPIC_08_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_09_NUMBER/#${EPIC_09_NUMBER}/g" plans/git-issues/EPIC_09_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_10_NUMBER/#${EPIC_10_NUMBER}/g" plans/git-issues/EPIC_10_ISSUE_*.md
SED_IN_PLACE "s/#EPIC_11_NUMBER/#${EPIC_11_NUMBER}/g" plans/git-issues/EPIC_11_ISSUE_*.md
```

After this, every child body's `Refs #EPIC_NN_NUMBER` line points at the right issue. Verify quickly:

```bash
grep -E 'EPIC_[0-9]{2}_NUMBER' plans/git-issues/EPIC_*_ISSUE_*.md || echo "all substitutions complete"
```

## Step 4 — File the 61 child issues in order

Convention: title is `feat(<scope>): <short description>` for code work, `chore(<scope>): ...` for docs/tooling. Each issue uses the labels declared in its file's bottom-most `## Labels` section. Below is the dense filing block. Each child also writes its returned issue number to a shell var so the epic's Child Issues checklist can be filled in afterward.

```bash
# EPIC 01 — Phase 0 Skeleton
E01_01=$(gh issue create --title "feat(skeleton): Create paired iOS + watchOS Xcode project, App Group, and capabilities" --body-file plans/git-issues/EPIC_01_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-0-skeleton" --json number --jq .number)
E01_02=$(gh issue create --title "feat(persistence): Wire SwiftData ModelContainer against the App Group URL" --body-file plans/git-issues/EPIC_01_ISSUE_02_swiftdata-container.md --label "spec-decomposition,core,phase-0-skeleton" --json number --jq .number)
E01_03=$(gh issue create --title "feat(sync): WCSession activation handshake on both targets" --body-file plans/git-issues/EPIC_01_ISSUE_03_wcsession-handshake.md --label "spec-decomposition,core,phase-0-skeleton,concurrency" --json number --jq .number)
E01_04=$(gh issue create --title "docs: Update CLAUDE.md Build/Test/Run and add top-level README.md" --body-file plans/git-issues/EPIC_01_ISSUE_04_build-test-run-docs.md --label "spec-decomposition,docs,phase-0-skeleton" --json number --jq .number)

# EPIC 02 — Phase 1 Data Model & Sync Tracer
E02_01=$(gh issue create --title "feat(models): Add empty @Model class shells for the SwiftData schema" --body-file plans/git-issues/EPIC_02_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-1-data-model" --json number --jq .number)
E02_02=$(gh issue create --title "feat(models): Fill the SwiftData schema body per SPEC §5.2 with Sendable review" --body-file plans/git-issues/EPIC_02_ISSUE_02_schema-body.md --label "spec-decomposition,core,phase-1-data-model,concurrency" --json number --jq .number)
E02_03=$(gh issue create --title "feat(models): Seed the ingredient library idempotently on first launch" --body-file plans/git-issues/EPIC_02_ISSUE_03_seeded-ingredient-library.md --label "spec-decomposition,core,phase-1-data-model" --json number --jq .number)
E02_04=$(gh issue create --title "feat(sync): Add RegimenSnapshot DTO and SwiftData converters with round-trip tests" --body-file plans/git-issues/EPIC_02_ISSUE_04_regimen-snapshot-dto.md --label "spec-decomposition,core,phase-1-data-model,concurrency" --json number --jq .number)
E02_05=$(gh issue create --title "feat(sync): Push hardcoded Stub Lithium from iPhone to watch via updateApplicationContext" --body-file plans/git-issues/EPIC_02_ISSUE_05_push-stub-medication.md --label "spec-decomposition,core,phase-1-data-model" --json number --jq .number)

# EPIC 03 — Phase 2 Maintenance Flow
E03_01=$(gh issue create --title "feat(regimen): Skeleton iPhone Regimen tab and watch RightNow view with stub queue" --body-file plans/git-issues/EPIC_03_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-2-maintenance" --json number --jq .number)
E03_02=$(gh issue create --title "feat(regimen): iPhone add/edit/archive form for maintenance medications" --body-file plans/git-issues/EPIC_03_ISSUE_02_iphone-add-edit-archive.md --label "spec-decomposition,core,phase-2-maintenance" --json number --jq .number)
E03_03=$(gh issue create --title "feat(watch): Tap-through queue with single-tap Mark Taken writing DoseEvents" --body-file plans/git-issues/EPIC_03_ISSUE_03_watch-tap-through-logging.md --label "spec-decomposition,core,phase-2-maintenance" --json number --jq .number)
E03_04=$(gh issue create --title "feat(notifications): Schedule UserNotifications on the watch with full-rebuild semantics" --body-file plans/git-issues/EPIC_03_ISSUE_04_notifications.md --label "spec-decomposition,core,phase-2-maintenance,notifications" --json number --jq .number)
E03_05=$(gh issue create --title "feat(sync): Reverse-sync DoseEvents from watch to iPhone via transferFile" --body-file plans/git-issues/EPIC_03_ISSUE_05_reverse-sync-dose-events.md --label "spec-decomposition,core,phase-2-maintenance" --json number --jq .number)
E03_06=$(gh issue create --title "feat(queue): Pending-queue selection logic with timezone and already-taken handling" --body-file plans/git-issues/EPIC_03_ISSUE_06_queue-selection-logic.md --label "spec-decomposition,edges,phase-2-maintenance" --json number --jq .number)

# EPIC 04 — Phase 3 High-Risk + Liquid Glass
E04_01=$(gh issue create --title "feat(design-system): Add LiquidGlassTheme tokens and glass-background extension" --body-file plans/git-issues/EPIC_04_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-3-high-risk,design-system" --json number --jq .number)
E04_02=$(gh issue create --title "feat(watch): Press-and-hold confirmation gesture with Liquid Glass ring" --body-file plans/git-issues/EPIC_04_ISSUE_02_press-and-hold-gesture.md --label "spec-decomposition,core,phase-3-high-risk" --json number --jq .number)
E04_03=$(gh issue create --title "feat(design-system): Apply glass effect and success shimmer across primary screens" --body-file plans/git-issues/EPIC_04_ISSUE_03_glass-effect-throughout.md --label "spec-decomposition,core,phase-3-high-risk,design-system" --json number --jq .number)
E04_04=$(gh issue create --title "feat(settings): User-tweakable press-and-hold duration synced to watch" --body-file plans/git-issues/EPIC_04_ISSUE_04_settings-hold-duration.md --label "spec-decomposition,edges,phase-3-high-risk" --json number --jq .number)
E04_05=$(gh issue create --title "test: Tap-through snapshot tests and Liquid Glass visual-review PR template" --body-file plans/git-issues/EPIC_04_ISSUE_05_snapshot-tests-and-visual-review.md --label "spec-decomposition,polish,phase-3-high-risk,tests" --json number --jq .number)

# EPIC 05 — Phase 4 PRN + Ingredient Safety
E05_01=$(gh issue create --title "feat(prn): Skeleton watch PRN section and iPhone PRN form with stub totals" --body-file plans/git-issues/EPIC_05_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-4-prn-safety" --json number --jq .number)
E05_02=$(gh issue create --title "feat(safety): Ingredient query helpers (totalToday, lastDoseTime) over denormalized snapshots" --body-file plans/git-issues/EPIC_05_ISSUE_02_ingredient-query-helpers.md --label "spec-decomposition,core,phase-4-prn-safety" --json number --jq .number)
E05_03=$(gh issue create --title "feat(safety): violationsIfTaken evaluator with the three Phase 4 gate tests" --body-file plans/git-issues/EPIC_05_ISSUE_03_violations-if-taken.md --label "spec-decomposition,core,phase-4-prn-safety" --json number --jq .number)
E05_04=$(gh issue create --title "feat(prn): Watch quantity picker and ingredient-aware row variants" --body-file plans/git-issues/EPIC_05_ISSUE_04_watch-quantity-picker-and-rows.md --label "spec-decomposition,core,phase-4-prn-safety" --json number --jq .number)
E05_05=$(gh issue create --title "feat(prn): Soft warning interstitial naming the at-risk ingredient" --body-file plans/git-issues/EPIC_05_ISSUE_05_soft-warning-interstitial.md --label "spec-decomposition,core,phase-4-prn-safety" --json number --jq .number)
E05_06=$(gh issue create --title "feat(regimen): iPhone Ingredients screen with disclaimer banner" --body-file plans/git-issues/EPIC_05_ISSUE_06_ingredients-screen.md --label "spec-decomposition,edges,phase-4-prn-safety" --json number --jq .number)

# EPIC 06 — Phase 5 Snooze-Until-Time
E06_01=$(gh issue create --title "feat(notifications): Register SNOOZE_UNTIL_TIME action with stub SnoozeView" --body-file plans/git-issues/EPIC_06_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-5-snooze,notifications" --json number --jq .number)
E06_02=$(gh issue create --title "feat(notifications): SnoozeRescheduler with post-midnight rollover" --body-file plans/git-issues/EPIC_06_ISSUE_02_reschedule-logic.md --label "spec-decomposition,core,phase-5-snooze,notifications" --json number --jq .number)
E06_03=$(gh issue create --title "feat(watch): Wire SnoozeView DatePicker to the rescheduler with Liquid Glass" --body-file plans/git-issues/EPIC_06_ISSUE_03_snooze-view-wired.md --label "spec-decomposition,core,phase-5-snooze" --json number --jq .number)
E06_04=$(gh issue create --title "feat(snooze): SnoozeRecord schema migration and fourth-snooze soft warning" --body-file plans/git-issues/EPIC_06_ISSUE_04_snooze-count-and-soft-warning.md --label "spec-decomposition,edges,phase-5-snooze" --json number --jq .number)
E06_05=$(gh issue create --title "feat(settings): Default snooze offset preference synced to watch" --body-file plans/git-issues/EPIC_06_ISSUE_05_default-snooze-offset-setting.md --label "spec-decomposition,polish,phase-5-snooze" --json number --jq .number)

# EPIC 07 — Phase 6 HealthKit Import
E07_01=$(gh issue create --title "feat(healthkit): Add Import from Apple Health entry with stub sheet and capability" --body-file plans/git-issues/EPIC_07_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-6-healthkit" --json number --jq .number)
E07_02=$(gh issue create --title "feat(healthkit): Per-medication HealthKit read authorization (iOS only)" --body-file plans/git-issues/EPIC_07_ISSUE_02_healthkit-authorization.md --label "spec-decomposition,core,phase-6-healthkit" --json number --jq .number)
E07_03=$(gh issue create --title "feat(healthkit): Query HKUserAnnotatedMedication and surface in import sheet" --body-file plans/git-issues/EPIC_07_ISSUE_03_query-and-import-sheet.md --label "spec-decomposition,core,phase-6-healthkit" --json number --jq .number)
E07_04=$(gh issue create --title "feat(healthkit): Map Health drafts to PillBreakfast Medication with manual ingredient confirmation" --body-file plans/git-issues/EPIC_07_ISSUE_04_map-to-medication.md --label "spec-decomposition,core,phase-6-healthkit" --json number --jq .number)
E07_05=$(gh issue create --title "feat(healthkit): Idempotent re-import keyed on healthKitConceptID" --body-file plans/git-issues/EPIC_07_ISSUE_05_idempotent-reimport.md --label "spec-decomposition,edges,phase-6-healthkit" --json number --jq .number)

# EPIC 08 — Phase 7 Widgets & Complication
E08_01=$(gh issue create --title "feat(widgets): Add watch widget extension with one stub circular complication" --body-file plans/git-issues/EPIC_08_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-7-widgets" --json number --jq .number)
E08_02=$(gh issue create --title "feat(widgets): Three complication families (circular, corner, inline) reading real data" --body-file plans/git-issues/EPIC_08_ISSUE_02_three-complication-families.md --label "spec-decomposition,core,phase-7-widgets" --json number --jq .number)
E08_03=$(gh issue create --title "feat(widgets): Smart Stack widget surfacing 15 min before scheduled doses" --body-file plans/git-issues/EPIC_08_ISSUE_03_smart-stack-widget.md --label "spec-decomposition,core,phase-7-widgets" --json number --jq .number)
E08_04=$(gh issue create --title "feat(widgets): LogNextDoseIntent for single-tap logging from Smart Stack" --body-file plans/git-issues/EPIC_08_ISSUE_04_log-next-dose-intent.md --label "spec-decomposition,core,phase-7-widgets" --json number --jq .number)
E08_05=$(gh issue create --title "feat(widgets): Background-refresh debouncer keeps complication current after dose writes" --body-file plans/git-issues/EPIC_08_ISSUE_05_background-refresh.md --label "spec-decomposition,edges,phase-7-widgets" --json number --jq .number)

# EPIC 09 — Phase 8 History / Export / Polish
E09_01=$(gh issue create --title "feat(history): Skeleton iPhone History tab with stub heatmap and drill-down" --body-file plans/git-issues/EPIC_09_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-8-history-export" --json number --jq .number)
E09_02=$(gh issue create --title "feat(history): 30-day heatmap and per-day drill-down with PRN running totals" --body-file plans/git-issues/EPIC_09_ISSUE_02_heatmap-and-drill-down.md --label "spec-decomposition,core,phase-8-history-export" --json number --jq .number)
E09_03=$(gh issue create --title "feat(history): Filter by medication on heatmap and drill-down" --body-file plans/git-issues/EPIC_09_ISSUE_03_filter-by-medication.md --label "spec-decomposition,edges,phase-8-history-export" --json number --jq .number)
E09_04=$(gh issue create --title "feat(export): PDFKit 30-day export reading denormalized ingredient snapshots" --body-file plans/git-issues/EPIC_09_ISSUE_04_pdf-export.md --label "spec-decomposition,core,phase-8-history-export" --json number --jq .number)
E09_05=$(gh issue create --title "feat(export): Share sheet integration via SwiftUI ShareLink" --body-file plans/git-issues/EPIC_09_ISSUE_05_share-sheet.md --label "spec-decomposition,core,phase-8-history-export" --json number --jq .number)
E09_06=$(gh issue create --title "chore(polish): Empty states and explicit error handling pass" --body-file plans/git-issues/EPIC_09_ISSUE_06_empty-states-and-errors.md --label "spec-decomposition,polish,phase-8-history-export" --json number --jq .number)
E09_07=$(gh issue create --title "chore(a11y): VoiceOver audit across iPhone and watch with explicit labels and traits" --body-file plans/git-issues/EPIC_09_ISSUE_07_voiceover-audit.md --label "spec-decomposition,polish,phase-8-history-export,a11y" --json number --jq .number)

# EPIC 10 — Phase 9 Hardening & Submission
E10_01=$(gh issue create --title "chore(submission): Scaffold Submission/ folder with templates and stubs" --body-file plans/git-issues/EPIC_10_ISSUE_01_skeleton.md --label "spec-decomposition,tracer-skeleton,phase-9-hardening" --json number --jq .number)
E10_02=$(gh issue create --title "chore(submission): App icons (1024 master + all derived sizes)" --body-file plans/git-issues/EPIC_10_ISSUE_02_app-icons.md --label "spec-decomposition,polish,phase-9-hardening" --json number --jq .number)
E10_03=$(gh issue create --title "chore(submission): Screenshots and marketing copy" --body-file plans/git-issues/EPIC_10_ISSUE_03_screenshots-and-marketing-copy.md --label "spec-decomposition,polish,phase-9-hardening" --json number --jq .number)
E10_04=$(gh issue create --title "feat(diagnostics): Crash reporting via MetricKit with ADR" --body-file plans/git-issues/EPIC_10_ISSUE_04_crash-reporting.md --label "spec-decomposition,core,phase-9-hardening" --json number --jq .number)
E10_05=$(gh issue create --title "chore(submission): Privacy nutrition labels honest with reality" --body-file plans/git-issues/EPIC_10_ISSUE_05_privacy-nutrition-labels.md --label "spec-decomposition,polish,phase-9-hardening" --json number --jq .number)
E10_06=$(gh issue create --title "test(mutation): Mutation testing on three critical safety modules to >=85%" --body-file plans/git-issues/EPIC_10_ISSUE_06_mutation-testing.md --label "spec-decomposition,core,phase-9-hardening,tests" --json number --jq .number)
E10_07=$(gh issue create --title "chore(submission): 5-day soak test on real hardware with diary" --body-file plans/git-issues/EPIC_10_ISSUE_07_soak-test.md --label "spec-decomposition,polish,phase-9-hardening" --json number --jq .number)

# EPIC 11 — Future Work (Placeholders)
E11_01=$(gh issue create --title "future: Pill imagery via NLM RxImage (SPEC §12.1)" --body-file plans/git-issues/EPIC_11_ISSUE_01_pill-imagery.md --label "spec-decomposition,future-work,needs-spec" --json number --jq .number)
E11_02=$(gh issue create --title "future: iCloud sync via CloudKit-backed SwiftData (SPEC §12.2)" --body-file plans/git-issues/EPIC_11_ISSUE_02_icloud-sync.md --label "spec-decomposition,future-work,needs-spec" --json number --jq .number)
E11_03=$(gh issue create --title "future: Caregiver mode (SPEC §12.3)" --body-file plans/git-issues/EPIC_11_ISSUE_03_caregiver-mode.md --label "spec-decomposition,future-work,needs-spec,v2" --json number --jq .number)
E11_04=$(gh issue create --title "future: Health dose readback enrichment (SPEC §12.4)" --body-file plans/git-issues/EPIC_11_ISSUE_04_health-dose-readback.md --label "spec-decomposition,future-work,needs-spec" --json number --jq .number)
E11_05=$(gh issue create --title "future: Apple Watch Ultra Action Button binding (SPEC §12.5)" --body-file plans/git-issues/EPIC_11_ISSUE_05_action-button-binding.md --label "spec-decomposition,future-work,needs-spec" --json number --jq .number)
E11_06=$(gh issue create --title "future: File Apple Feedback Assistant request for HKMedicationDoseEvent write (SPEC §12.6)" --body-file plans/git-issues/EPIC_11_ISSUE_06_apple-feedback-request.md --label "spec-decomposition,future-work,needs-spec,advocacy" --json number --jq .number)
```

## Step 5 — Update each epic's Child Issues checklist

After all children are filed, edit each epic's body to fill in the checklist with the real issue numbers. Easiest: maintain a `plans/git-issues/_edits/EPIC_NN_filled.md` per epic with the real numbers substituted, then:

```bash
gh issue edit $EPIC_01_NUMBER --body-file plans/git-issues/_edits/EPIC_01_filled.md
gh issue edit $EPIC_02_NUMBER --body-file plans/git-issues/_edits/EPIC_02_filled.md
# ...and so on through EPIC_11.
```

The `_edits/` files are not authored in this decomposition because the real issue numbers are not yet known. The parent agent generates them after Step 4 returns, ideally with a small Python script that:

1. Loads `EPIC_NN_<slug>.md`.
2. Locates the `## Child Issues` section.
3. Replaces the `#NNN` lines with the real numbers from `$E01_01` through `$E11_06`.
4. Writes to `_edits/EPIC_NN_filled.md`.

## Step 6 — Sanity output

```bash
echo "Decomposition filed. Summary:"
echo "  Epics:    11 (numbers ${EPIC_01_NUMBER} through ${EPIC_11_NUMBER})"
echo "  Children: 61"
echo "  First issue to start: #${E01_01} (EPIC 01 ISSUE 01 — Skeleton)"
echo "  Source of truth files: plans/git-issues/ (commit these to git)"
```

## Step 7 — Commit the decomposition files to git

Per Step 9 of the skill, commit the `plans/git-issues/` directory so the trail of how the backlog was generated is preserved.

```bash
git add plans/git-issues/
git commit -m "$(cat <<'EOF'
Decompose SPEC into 11 epics and 61 child issues

Files written to plans/git-issues/ per the spec-decomposition skill,
deviating from the skill's recommended top-level git-issues/ because
plans/ is this repo's existing convention (CLAUDE.md). See
plans/git-issues/2026-05-15_SPEC_summary.md for the index.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

## Notes for the parent agent

- **Directory deviation.** The skill writes to top-level `git-issues/`; this decomposition uses `plans/git-issues/` because CLAUDE.md establishes `plans/` as the home for all SPEC-adjacent material. If you'd rather move the directory to top-level, do it before filing — every `--body-file` path in this plan would need the prefix dropped.
- **Filing is irreversible.** Do not file until the user has reviewed at least one full epic body and one full child body. The skill's Step 7 dry-run gate exists for exactly this.
- **One non-trivial gap surfaced during decomposition,** documented inline in `EPIC_05_ISSUE_03_violations-if-taken.md`: SPEC §10 Phase 4 case 3's worked example (1500mg Tylenol + 4 Excedrin Extra Strength) does not actually trip the 4000mg acetaminophen ceiling — 1500 + (4 * 250) = 2500mg. The issue body proposes a fixture adjustment so the killer test legitimately fires; flag this to Geoff before merging EPIC 05 issue 03 so we can either tweak the fixture or revise the SPEC paragraph.
