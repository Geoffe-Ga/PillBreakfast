# SPEC — Issue #66: 5-Day Soak Test on Real Hardware with Diary

| Field | Value |
|---|---|
| Issue | #66 |
| Phase | 9 — Hardening & Submission Prep |
| Labels | `spec-decomposition`, `polish`, `phase-9-hardening` |
| Status | Draft |
| Date | 2026-06-07 |
| Parent epic | #10 |
| Related issues | #61 (icon in place before soak), #62 (screenshots before soak; copy may need correction based on soak findings), mutation-testing issue (must land before soak so safety paths are exercised honestly) |

---

## 1. Summary

Define and execute a structured 5-day dogfooding protocol on Geoff's own paired iPhone + Apple
Watch hardware, using his real ~12-pills/day regimen including lithium. The protocol produces a
`soak-diary-<start-date>.md` file with daily entries, a final bug summary, and any follow-up issues
for critical findings. Exit criterion: no unresolved critical bugs (defined as anything that causes
a missed dose, double dose, or data loss).

This spec defines the diary format, the set of signals to capture each day, the daily checklist,
the severity triage scheme, and the process for converting findings into tracked issues.

---

## 2. Problem Statement / Motivation

Simulators and unit tests exercise happy-path logic and known edge cases. Real hardware over
multiple days exercises the unexpected: battery behavior under load, notification delivery in
background app states the simulator cannot replicate, WatchConnectivity sync reliability as the
phone and watch move between Bluetooth and WiFi proximity ranges, complication freshness after
watch face rotation, and the human factors of the logging ritual at 8 AM half-awake.

The SPEC §10 Phase 9 gate explicitly requires "5-day soak test on real hardware" as a precondition
to the TestFlight submission. This spec operationalizes that gate into a repeatable QA protocol
with clear exit criteria.

The safety dimension is not hypothetical. Lithium has a narrow therapeutic window; a double-dose
event or a missed notification is a real-world risk outcome, not a UX annoyance. This is why the
"critical bug" definition in the issue brief is specifically anchored to missed dose, double dose,
and data loss — not to aesthetic issues or minor UX friction.

---

## 3. Goals & Non-Goals

**Goals:**
- A structured diary template that captures the right signals without being so burdensome it
  defeats the dogfooding purpose
- Clear signal taxonomy: notification behavior, sync latency, complication freshness, battery,
  crashes, safety-path events, snooze behavior
- Severity triage scheme with unambiguous critical/non-critical split
- Daily checklist that takes less than 5 minutes to fill in
- Exit criteria tied directly to the SPEC §10 Phase 9 gate
- Process for converting soak findings into GitHub issues (one issue per critical bug, filed before
  the soak PR merges)

**Non-Goals:**
- Beta tester recruitment — this is single-user dogfooding; Geoff is the sole tester for v1
- Automated crash symbolication pipeline (MetricKit delivers crash reports to the app's Diagnostics
  folder; Geoff reads them manually during the soak)
- Performance profiling (Instruments sessions, Energy Log traces) — that belongs in a dedicated
  perf hardening issue if needed
- Regression testing (that is the automated test suite's job; the soak catches what unit tests miss)

---

## 4. Background & Current State

### What exists

`Submission/soak-diary-TEMPLATE.md` is a two-line stub placeholder ("Per-day log Geoff keeps
during the 30-day soak..."). The actual template and protocol are undefined. This spec defines both.

The issue brief specifies **5 consecutive days** (the SPEC originally mentioned 30 days in the
`soak-diary-TEMPLATE.md` header, but the issue brief and SPEC §10 gate both say 5 days; the
5-day figure governs).

### Real hardware context

Geoff's daily regimen includes approximately 12 medications across maintenance and PRN categories,
including:
- Lithium (safety-critical, high-risk, press-and-hold required — SPEC §7.2)
- Gabapentin as PRN (ingredient-aware ceiling, min-interval checks — SPEC §7.3)
- Various maintenance supplements

This is a real medication regimen with real safety implications. The soak protocol treats the
app as a safety-adjacent tool, not a lifestyle app. The diary captures potential near-miss events
(cases where the app's UI or notification system could have contributed to a missed or double dose)
with the same attention as actual incidents.

### Notification architecture

Notifications are scheduled directly on the watch (`UserNotifications`, `UNCalendarNotificationTrigger`)
so they fire without the iPhone present. The soak must exercise both the Bluetooth-connected and
Bluetooth-out-of-range states to verify this independence. See SPEC §8.1.

### WatchConnectivity sync

Regimen changes on iPhone propagate via `updateApplicationContext`. Dose events flow from watch to
iPhone via file transfer (`WCSession.transferFile`). Both directions must be verified during the
soak. The sync is not real-time — the `applicationContext` path delivers on next watch app launch
if the watch is unreachable; file transfers queue and deliver when connectivity restores.

---

## 5. Detailed Design / Plan

### 5.1 Pre-soak setup checklist

Complete the following before Day 1:

- [ ] Build and install the TestFlight (or direct-install Debug) build on real iPhone and paired
      Apple Watch
- [ ] Verify both devices are on iOS 26 and watchOS 26
- [ ] Add Geoff's complete real regimen in the iPhone Regimen tab (all maintenance meds with correct
      schedules; all PRN meds with correct ceilings and quantities)
- [ ] Confirm all maintenance meds that are high-risk (lithium) have `isHighRisk: true` in the
      ingredient library — press-and-hold must be required from Day 1
- [ ] Add at least one complication to the watch face that shows pending dose count
- [ ] Verify `WC state: activated` on both devices
- [ ] Note the iOS build number and watchOS build number in the diary header
- [ ] Note the iPhone model and Apple Watch model/size in the diary header
- [ ] Set `Settings > General > Background App Refresh` to ON for PillBreakfast on iPhone (required
      for WatchConnectivity background delivery)

### 5.2 Daily checklist

Each day, after the last scheduled dose window of the day, fill in the diary entry using the
template in §5.5. The minimum required fields are marked with (Required). All other fields are
"fill in if relevant."

The checklist should take 3–5 minutes per day. Do not postpone to the next day — diary entries
written from memory 24+ hours later are not reliable for timing-sensitive signals like notification
delivery latency.

### 5.3 Signal taxonomy

The following signals must be explicitly assessed each day. A signal with no incident is recorded
as "nominal" — do not leave it blank (blank is ambiguous with "didn't check").

| Signal | What to capture | Why it matters |
|---|---|---|
| **Notification delivery** | Did every scheduled dose notification fire? What was the delay relative to scheduled time (estimate to nearest minute)? Did the notification appear on both watch and iPhone, or only one? | Primary dose-trigger mechanism; missed notification = missed dose risk |
| **Notification content** | Title, body, action buttons present and correct? Names in the body match the scheduled dose? | Wrong content could cause confusion about what to take |
| **Tap-through queue accuracy** | On opening from notification, was the queue ordered correctly? Were there any phantom entries or missing entries? | Queue errors = wrong dose logged or dose missed |
| **Press-and-hold behavior** | For lithium (and any other high-risk med): did the hold gesture work reliably? Any accidental triggers? Any failures to register a valid hold? | Safety-critical; double dose or missed log are both bad outcomes |
| **PRN running totals** | After logging a PRN dose, did the total update correctly in the PRN list? Was the last-dose timestamp accurate? | Incorrect totals undermine the safety-check feature |
| **Safety warning trigger** | If any ceiling or interval check fired: was the warning accurate (correct ingredient, correct amounts)? Could it be overridden? | Over-triggering = warning fatigue; under-triggering = safety miss |
| **Sync latency (watch → phone)** | After logging a dose on the watch, how long until it appears in iPhone history? (Bluetooth connected vs. phone in another room) | Data loss risk if sync is fragile; also relevant for PDF export freshness |
| **Complication freshness** | After logging a dose, did the watch face complication update the pending count promptly? Maximum acceptable: 5 minutes | Stale complication shows wrong pending count; user thinks they haven't logged |
| **Snooze behavior** | If snoozed: did the notification re-fire at the selected time? Was the snoozed-dose state correctly persisted? Did the 3-snooze warning trigger on the 4th snooze? | Snooze is the second most common user interaction after confirm |
| **Battery impact** | Note watch battery level at wake and at sleep (or end of day). Note any unusual iPhone battery drain. | Background tasks and BLE can eat battery; abnormal drain triggers investigation |
| **Crashes / unexpected exits** | Did either app crash or unexpectedly exit? What were you doing? Was the dose state preserved after relaunch? | Crash during dose logging = unrecorded dose = missed/double dose risk |
| **Data integrity check** | At end of day, compare the iPhone History view against what you recall logging on the watch. Any discrepancies? | Detects silent data loss or sync failures |

### 5.4 Severity triage

| Severity | Definition | Required action |
|---|---|---|
| **Critical** | Caused or could have caused a missed dose, double dose, or data loss. Definition from issue brief. | File a GitHub issue immediately. Do not merge the soak PR until the issue is filed and (if possible) fixed. Soak ends early if a critical bug is not fixable within the 5-day window — file the issue, re-run a fresh 5-day soak after the fix is merged. |
| **High** | Significant UX degradation that would prevent a real user from completing dose logging, but did not cause the above outcomes in this session (e.g., app hung and required force-quit, but dose state was preserved). | File a GitHub issue before merge. Can merge soak PR with the issue filed and linked. |
| **Medium** | Noticeable friction or inaccuracy that does not threaten dose logging (e.g., complication takes 10 min to update instead of 5, PRN row shows slightly wrong "last taken" time). | File a GitHub issue. Can merge soak PR. |
| **Low** | Aesthetic or copy issue, minor UX friction. | Note in diary. File a GitHub issue if actionable. Does not block merge. |
| **Observation** | Something that worked but surprised you, or a behavioral note for future design consideration. | Note in diary only. No issue required. |

### 5.5 Diary template

One file per soak run: `Submission/soak-diary-<start-date>.md` where `<start-date>` is the ISO
date of Day 1 (e.g., `soak-diary-2026-06-10.md`).

```markdown
# Soak Diary — PillBreakfast v1.0

**Build:** <!-- iOS build number and watchOS build number -->
**Hardware:** <!-- iPhone model, iOS version / Apple Watch model+size, watchOS version -->
**Soak start date:** <!-- YYYY-MM-DD -->
**Real regimen loaded:** <!-- Yes / No — confirm before Day 1 -->

---

## Day 1 — YYYY-MM-DD

### Morning dose window (scheduled: HH:MM)

**Notification delivery:** <!-- nominal / late by N min / did not fire -->
**Notification content:** <!-- nominal / issue: <describe> -->
**Tap-through queue:** <!-- nominal / issue: <describe> -->
**Press-and-hold (high-risk meds):** <!-- nominal / issue: <describe> / N/A -->
**After-logging queue state:** <!-- advanced correctly / issue: <describe> -->

### Afternoon / evening dose windows (if any)

<!-- Repeat the above block for each additional scheduled window, or write "no afternoon doses" -->

### PRN doses taken today

<!-- List any PRN doses: medication name, time, quantity, running total shown, accuracy -->
<!-- If no PRN doses: "none" -->

### Safety warnings triggered

<!-- List any ceiling/interval warnings: accurate / false positive / false negative -->
<!-- If none: "none" -->

### Sync & complication

**Watch → iPhone sync latency:** <!-- estimate; note if Bluetooth connected or not -->
**Complication update latency:** <!-- after last log; nominal (<5 min) / slow: N min / did not update -->

### Snooze events

<!-- Any snooze interactions today: time snoozed to, did it fire correctly, 3-snooze warning if applicable -->
<!-- If none: "none" -->

### Battery

**Watch battery: start of day** <!-- % at wake -->
**Watch battery: end of day** <!-- % at sleep -->
**iPhone battery: unusual drain?** <!-- Yes (describe) / No -->

### Crashes / unexpected exits

<!-- App, crash type if known, what you were doing, dose state after relaunch -->
<!-- If none: "none" -->

### End-of-day data integrity check

**iPhone History matches logged doses:** <!-- Yes / discrepancy: <describe> -->

### Incidents & observations

<!-- Any incident not captured above, rated by severity -->
<!-- Format: [CRITICAL|HIGH|MEDIUM|LOW|OBSERVATION] Brief description -->

---

## Day 2 — YYYY-MM-DD

<!-- (same structure as Day 1) -->

---

## Day 3 — YYYY-MM-DD

<!-- (same structure as Day 1) -->

---

## Day 4 — YYYY-MM-DD

<!-- (same structure as Day 1) -->

---

## Day 5 — YYYY-MM-DD

<!-- (same structure as Day 1) -->

---

## Final Summary

### Critical bugs

| # | Description | GitHub issue | Status |
|---|---|---|---|
| <!-- number --> | <!-- description --> | <!-- #N --> | <!-- open / fixed before merge --> |

### High bugs

| # | Description | GitHub issue | Status |
|---|---|---|---|

### Medium bugs

| # | Description | GitHub issue |
|---|---|---|

### Low / Observations

<!-- Bulleted list; no issue numbers required -->

### Exit verdict

<!-- One of: -->
<!-- PASS — no critical bugs unresolved; ready for TestFlight submission -->
<!-- FAIL — N critical bug(s) unresolved; soak must be repeated after fixes -->

### Follow-up issues filed

<!-- List all GitHub issues filed as a result of this soak run -->
```

---

## 6. Assets & Deliverables

| Path | Description |
|---|---|
| `Submission/soak-diary-<start-date>.md` | The completed diary (one file per soak run) |
| GitHub issues (filed separately) | One per critical bug; linked from the diary Final Summary |

The `Submission/soak-diary-TEMPLATE.md` stub does not need to be updated; the template above
(§5.5) supersedes it. The actual diary files are dated instances.

---

## 7. Edge Cases & Failure Modes

**Critical bug found on Day 2.** If a critical bug surfaces mid-soak, the soak is paused,
the bug is filed as a GitHub issue, and the fix is expedited. Once the fix is merged and a new
build is installed on the hardware, the 5-day clock restarts from Day 1. Do not resume counting
days from the point of interruption — the point of 5 consecutive days is to surface timing-
dependent bugs (e.g., notification accumulation over days, week-boundary edge cases in scheduling).

**Regimen change during the soak.** If Geoff makes a regimen change during the soak (adds, edits,
or archives a medication), note it in that day's diary and verify that the notification rebuild
fires correctly on the watch. This is a valuable test of the regimen-change path but it complicates
the "nominal" baseline — note the change explicitly.

**Watch reboot or re-pair during the soak.** If the watch is unpaired and re-paired, SwiftData on
the watch is wiped and must be re-seeded via WatchConnectivity. This is a data loss scenario if
unhandled. Note the event and verify that the regimen re-syncs completely within 5 minutes of
re-pairing. If it does not, this is a critical bug.

**iPhone unavailable for a day.** Notifications should still fire from the watch directly. The sync
will queue and deliver when the iPhone is reachable. Test this explicitly: leave the iPhone in
another room for a dose window on Day 3 or Day 4 and verify notification + logging still work.

**Soak during travel / timezone change.** Schedule-based notifications use `UNCalendarNotificationTrigger`
with local time. A timezone change mid-soak will shift notification times relative to the regimen.
Note any travel in the diary and verify notifications adjusted correctly. If the app does not handle
timezone changes gracefully, that is a high-severity bug.

**Missed dose due to app behavior vs. user error.** The diary does not adjudicate intent — if a
notification fired late and Geoff missed a dose, that is recorded as a notification latency incident
regardless of whether Geoff would have taken the medication anyway. The goal is an honest record of
app behavior, not a guilt log.

---

## 8. Verification / Acceptance Criteria

**Soak completion:**
- [ ] 5 consecutive calendar days of diary entries are present, each with all Required fields filled
- [ ] Every notification delivery event (fired/missed/late) is logged
- [ ] At least one PRN dose interaction is logged during the soak (if Geoff does not take any PRN
      meds during the 5 days, note it in the diary and explain why the PRN safety path was not
      exercised in the live regimen; flag for UITest coverage instead)
- [ ] At least one snooze interaction is performed and logged (engineer may snooze a dose
      intentionally on Day 2 or 3 to exercise this path)
- [ ] The watch was left out of Bluetooth range of the iPhone for at least one dose window and the
      outcome noted

**Exit criteria (Phase 9 gate):**
- [ ] Zero unresolved critical bugs (missed dose, double dose, or data loss) at time of PR merge
- [ ] All critical bugs found (if any) have been filed as GitHub issues and resolved before merge,
      OR the PR is explicitly marked "soak FAIL" with the critical issues linked, and a follow-up
      soak is scheduled

**Process:**
- [ ] `Submission/soak-diary-<start-date>.md` present with 5 daily entries and a Final Summary
- [ ] Final Summary includes a table of critical and high bugs, each with a GitHub issue number
- [ ] Exit verdict is present and is either "PASS" or "FAIL" with rationale
- [ ] `pre-commit run --all-files` is clean (diary is a Markdown file; no Swift changes expected)
- [ ] PR opened with `Refs #10` and `Closes #66`

---

## 9. Risks & Open Questions

**Risk: soak requires a real medication regimen.** Unlike other issues in this project, this one
cannot be delegated to the Ralph loop or an automated agent. Geoff is the tester. The protocol is
designed to be low-overhead (3–5 min/day) but it requires his active participation for 5 days.
Schedule the soak to start at a time with no planned travel or disruption to the normal daily
routine.

**Risk: iOS/watchOS 26 beta instability.** If the OS betas are unstable during the soak window,
some bugs may be OS-level rather than PillBreakfast-level. Note any OS crashes or system-level
issues in the diary and use "OBSERVATION" severity (not "CRITICAL") unless the app's data is
affected. File OS bugs with Apple Feedback Assistant separately; do not file them as PillBreakfast
issues.

**Risk: notification delivery on watchOS 26.** UserNotifications on watchOS has historically had
delivery quirks around do-not-disturb, theatre mode, sleep mode, and cover-to-mute. These should
be noted as observations if they affect delivery. If they affect delivery in a way that changes the
app's notification scheduling strategy, that is a high-severity finding.

**Open question: should the soak run 5 days or 7?** The issue brief and SPEC §10 both say 5. The
`soak-diary-TEMPLATE.md` header mentioned 30, but that stub was placeholder copy. Five days is
adopted here. If the first soak produces a critical bug and a second soak is needed after the fix,
the second soak only needs to cover the failing scenario plus one full day to verify stability —
a fresh 5-day run is not required for the second pass unless the critical bug was systemic.

**Open question: crash log access.** MetricKit delivers crash logs as `MXDiagnosticPayload`
objects to the app on next launch after a crash. PillBreakfast writes them to the App Group's
`Diagnostics/` folder (per `plans/decisions/2026-05-29_crash-reporting.md`). During the soak,
check this folder after any crash. If a crash is noted in the diary, attach the relevant
`MXCrashDiagnostic` summary (sanitized of any personal data) as a comment on the filed GitHub
issue.

---

## 10. Decomposition Hints

This issue is not decomposable in the traditional sense — it is a time-sequential single-person
activity. However, two sub-tasks exist that can be completed before the soak starts:

1. **Pre-soak setup** (Day 0): build installation, regimen entry, complication setup, baseline
   verification. This can be its own commit to the diary file.
2. **Soak execution** (Days 1–5): daily diary entries. Commit each day's entry the same day.
3. **Post-soak close-out** (Day 6): write Final Summary, file any issues, open PR.

Keeping day-by-day commits gives the reviewer a timestamped record and protects against diary
loss from a hardware failure on Day 4.

---

## 11. References

- SPEC §7.2 — Tap-through queue and press-and-hold gesture (signal: press-and-hold behavior)
- SPEC §7.3 — PRN section and safety checks (signal: PRN running totals, safety warning trigger)
- SPEC §7.4 — Complication (signal: complication freshness)
- SPEC §8 — Notifications and snooze flow (signal: notification delivery, snooze behavior)
- SPEC §10 Phase 9 — "5-day soak test on real hardware" as the explicit gate
- CLAUDE.md — "High-risk = press-and-hold" and "Snooze is snooze-until-time" conventions
- `Submission/soak-diary-TEMPLATE.md` — original stub (superseded by §5.5 template)
- `plans/decisions/2026-05-29_crash-reporting.md` — MetricKit crash log location
- Issue #61, #62 — must be complete before soak starts (icon and screenshots in place)
- Mutation-testing issue — must land before soak so safety paths are exercised honestly
