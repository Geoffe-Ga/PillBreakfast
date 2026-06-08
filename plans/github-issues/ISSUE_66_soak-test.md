## Role

You are the sole dogfooder and QA lead for PillBreakfast v1, running a structured 5-day soak test on your own paired iPhone + Apple Watch hardware with your real ~12-pills/day regimen (including lithium). This issue is **not** delegable to the Ralph loop or any automated agent — it requires a human taking real medications across real days. The deliverable is a completed, dated soak diary plus any follow-up issues for critical findings.

## Goal

Define the soak protocol (already specified in the SPEC §5) and execute it: 5 consecutive calendar days of diary entries against the live regimen, capturing the full signal taxonomy each day, triaging findings by severity, and converting every critical/high finding into a filed GitHub issue. Exit only when there are **zero unresolved critical bugs** — where "critical" is anchored to *missed dose, double dose, or data loss* — which is the SPEC §10 Phase 9 gate.

## Context

- **Parent epic:** #66 (this is the single atomic issue for the soak — it is filed directly, not decomposed). Cross-references phase epic **#10** (Phase 9 — Hardening & Submission) in sequencing.
- **Predecessors (must be merged before the soak starts):**
  - #61 (app icon in the asset catalogs — the shipped icon is on the home screen/grid during the soak).
  - #62 (screenshots + marketing copy — soak findings may surface copy corrections, so screenshots come first).
  - The mutation-testing issue — must land first so the safety paths are exercised honestly by the suite before the live run.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-66_soak-test.md` §5 (protocol: pre-soak checklist, daily checklist, signal taxonomy, severity triage, diary template), §7 (edge cases), §8 (acceptance / exit criteria).
- **Files involved:**
  - `Submission/soak-diary-<start-date>.md` (new — the dated diary instance, `<start-date>` = ISO date of Day 1, e.g. `soak-diary-2026-06-10.md`).
  - `Submission/soak-diary-TEMPLATE.md` (existing stub — **superseded** by SPEC §5.5; not updated by this issue).
  - `plans/decisions/2026-05-29_crash-reporting.md` (MetricKit crash-log location: App Group `Diagnostics/` folder — read after any crash).
- **Prior decisions (locked):**
  - **5 consecutive days**, not 30 (SPEC §10 gate and issue brief govern; the old TEMPLATE header's "30 days" was placeholder copy).
  - **Critical = missed dose / double dose / data loss only.** Aesthetic and minor-UX issues are never critical.
  - **A critical bug restarts the 5-day clock** after the fix is merged and reinstalled — do not resume counting from the interruption point.
  - High-risk meds (lithium) require press-and-hold from Day 1; this gesture is a first-class soak signal.
  - Snooze is snooze-until-time; the 4th consecutive snooze must trigger the soft warning (exercise this deliberately).
  - OS-level beta bugs are filed with Apple Feedback Assistant and recorded as `OBSERVATION`, not `CRITICAL`, unless app data is affected.

## Output Format

A single PR (committed day-by-day to protect against hardware failure mid-soak) containing:

- [ ] `Submission/soak-diary-<start-date>.md` created from the SPEC §5.5 template, with a filled header (iOS + watchOS build numbers, iPhone + Apple Watch model/size, soak start date, "real regimen loaded: Yes").
- [ ] A completed **pre-soak setup** entry (Day 0): build installed on real hardware, full real regimen entered, lithium confirmed `isHighRisk: true`, complication added showing pending count, `WC state: activated` on both devices, Background App Refresh ON.
- [ ] **5 daily entries** (Day 1–Day 5), each with every Required field filled and every signal in the taxonomy explicitly assessed — a no-incident signal is recorded as `nominal`, never left blank.
- [ ] Across the soak, the following are exercised and logged at least once: a PRN dose interaction (or an explicit note + UITest-coverage flag if none occurred naturally), one deliberate snooze, and one dose window with the watch left out of Bluetooth range of the iPhone.
- [ ] A **Final Summary** with the critical/high/medium bug tables (each row linking a filed GitHub issue number), a Low/Observations list, an **Exit verdict** of `PASS` or `FAIL` with rationale, and a list of all follow-up issues filed.
- [ ] One GitHub issue filed per critical bug (and per high bug), linked from the Final Summary. Critical issues must be resolved before merge, or the PR is explicitly marked "soak FAIL" with the issues linked and a follow-up soak scheduled.

## Examples

A representative filled daily-entry signal block (from the SPEC §5.5 template):

```markdown
## Day 2 — 2026-06-11

### Morning dose window (scheduled: 08:00)

**Notification delivery:** late by 2 min (watch fired 08:02; iPhone fired 08:02)
**Notification content:** nominal
**Tap-through queue:** nominal — 7 pending in correct order
**Press-and-hold (high-risk meds):** nominal — lithium hold registered first try
**After-logging queue state:** advanced correctly

### PRN doses taken today

Med D (gabapentin-class), 14:10, 1 capsule. Running total updated to 600 mg, last-dose timestamp accurate.

### Sync & complication

**Watch → iPhone sync latency:** ~40 s, Bluetooth connected
**Complication update latency:** nominal (<5 min)

### Incidents & observations

[OBSERVATION] Notification fired with a ~2 min delay both days so far — within tolerance, watching for a trend.
[MEDIUM] PRN row "last taken" briefly showed the prior dose for ~3 s after logging, then corrected. Filed #NNN.
```

## Constraints

**Scope fence:** Execute and document the soak; file issues for findings. **No** code changes are expected in this PR (the diary is Markdown). Any *fix* for a found bug is its own issue/PR, not part of this one. **No** beta-tester recruitment, no automated crash-symbolication pipeline, no Instruments perf profiling — all explicitly out of scope per SPEC §3.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The diary itself is the running tracer — at the end of each soak day the diary must stand on its own as an honest, timestamped record of that day's app behavior, even if a hardware failure ends the soak early. Never reconstruct a day's timing-sensitive signals (notification latency especially) from 24-hour-old memory.

## Done-Done

This is a process issue, not a code-touching one. The usual build/test gates do not apply (no Swift changes); the deliverable is the completed diary plus filed follow-up issues. The soak exit criteria from SPEC §8 are the real Done-Done:

- [ ] `Submission/soak-diary-<start-date>.md` is present with the pre-soak entry, 5 consecutive daily entries (all Required fields filled, every signal assessed), and a Final Summary.
- [ ] Every notification delivery event (fired/missed/late) is logged; at least one PRN interaction, one snooze, and one out-of-range dose window are exercised and recorded (or explicitly explained + flagged for UITest coverage).
- [ ] **Zero unresolved critical bugs** (missed dose / double dose / data loss) at merge — every critical/high finding has a filed GitHub issue linked from the Final Summary; criticals are fixed before merge, OR the PR is explicitly marked "soak FAIL" with the issues linked and a follow-up soak scheduled.
- [ ] Final Summary includes the bug tables, all follow-up issue numbers, and an Exit verdict of `PASS` or `FAIL` with rationale.
- [ ] `pre-commit run --all-files` is clean (the diary is Markdown; no Swift changes expected).
- [ ] PR opened with `Closes #66` and `Refs #10`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`
