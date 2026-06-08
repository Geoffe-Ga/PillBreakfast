## Role

You are the maintainer filing an Apple Feedback Assistant **enhancement request** asking Apple to let third-party apps write `HKMedicationDoseEvent` for the user's own data, under the same explicit per-medication authorization model that already governs reads. This is **advocacy, not code** — the deliverable is a filed Feedback report, its `FBxxxxxxxx` ID, and an archived copy of the submission committed to the repo. The one step a Ralph loop cannot perform autonomously is the actual Feedback Assistant submission (it requires a human signed into Geoff's developer Apple ID); everything else — finalizing the text, committing the archive, cross-linking, and recording the ID — is in scope.

## Goal

File one focused, well-argued Feedback Assistant request (Suggestion / API enhancement, Area: HealthKit — Medications) for third-party `HKMedicationDoseEvent` **write** access scoped to the user's own data under per-medication authorization. Capture the assigned Feedback ID, commit the verbatim submission to `Submission/apple-feedback-medications-write.md` (including the ID once assigned), cross-link the ID from SPEC §3 and issue #70, and record a follow-up cadence. The issue stays **open** as a passive tracker until Apple resolves it.

## Goal — why it matters (one line)

A single API change would let watch-first trackers contribute their watch-logged doses back to Health, collapsing the dual-source disagreement problem and obviating the asymmetric half of #70 (which can only *read* Health to suppress prompts, never make PillBreakfast's doses appear in Health).

## Context

- **Parent epic:** #72 (this issue *is* the atomic unit — there is no decomposition; the spec's hints #72a–#72d are small sequential steps that ship as this one issue plus the human filing step).
- **Predecessors:** none (non-blocking advocacy; nothing in v1 depends on the outcome). File early so any eventual Apple action lands before v2 design.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-72_apple-feedback-request.md` §5 (the submission plan — channel, evidence, follow-up, the ready-to-file draft in §5.5), §4.2 (what write access would unlock — the §3.4 tie-back table), §8 (process failure modes), §9 (privacy — no real PHI in the submission), §13 (acceptance criteria).
- **Files involved:**
  - `Submission/apple-feedback-medications-write.md` (new) — the verbatim submitted text + the assigned `FBxxxxxxxx` ID. The only repo change.
  - `plans/SPEC.md` §3 — cross-link the Feedback ID into the decision record so a future v2-dual-write contributor finds the outstanding request immediately.
  - `plans/2026-06-07_SPEC_ISSUE-72_apple-feedback-request.md` §5.5 — the source of the ready-to-file draft (do not modify the spec; copy the draft verbatim into the submission archive).
  - (evidence to attach to the Feedback report, not the repo) `PillBreakfast/HealthKitImport/` — the shipped read-only import flow that proves PillBreakfast is a legitimate Health consumer already using the read side; `Shared/Models/Medication.swift` (`healthKitConceptID`).
- **Prior decisions (locked):**
  - **Channel:** Apple Feedback Assistant (`feedbackassistant.apple.com`), the official enhancement-request path that routes to HealthKit engineering — **not** a DTS incident (DTS answers current behavior, already known: read-only).
  - **One** focused report, filed under Geoff's developer Apple ID. No duplicate/repeated reports; no forum/social campaign as part of this issue (a forum cross-link is optional).
  - The requested capability is framed as **privacy-preserving**: user-own-data only, under the **same explicit per-medication authorization model that already gates reads**. No new consent paradigm.
  - **No real PHI** in the submission. If a screen recording is attached, it must use seeded/demo medications only — never real dose history.
  - **No code** ships and **no speculative write-path** is built (explicit non-goal; that would be a future v2 SPEC tied to the outcome).
  - HealthKit Medications is **read-only and iOS-only** today; `healthKitConceptID` is a read-side link, never a write channel. This request asks to change the write half for the user's own dose events only — medications themselves stay defined in Health.

## Output Format

The deliverable is the **filed Feedback Assistant request**, not a code PR. Concretely:

- [ ] The Feedback Assistant report is submitted using the verbatim draft below (from spec §5.5) and the assigned **Feedback ID** (`FBxxxxxxxx`) is captured.
- [ ] `Submission/apple-feedback-medications-write.md` is committed, containing the submitted text **verbatim** plus the Feedback ID once assigned, and a follow-up cadence note.
- [ ] SPEC §3 is updated to reference the Feedback ID (discoverable from the decision record), and issue #70 is cross-linked.
- [ ] This issue records the Feedback ID and a follow-up date and **remains open** as a passive tracker (or is closed only with a citable Apple resolution).

The verbatim text to file and archive (spec §5.5):

> **Title:** Allow third-party apps to write `HKMedicationDoseEvent` for the user's own data, under per-medication authorization
>
> **Area:** HealthKit — Medications
>
> **Type:** API enhancement / suggestion
>
> **Description:**
>
> The HealthKit Medications API introduced in iOS 26 exposes `HKUserAnnotatedMedication` and `HKMedicationDoseEvent` as **read-only** for third-party apps (confirmed by Apple DTS: "Medication data is read-only in HealthKit"). Apps can consume the user's medications and dose events but cannot contribute. We request that Apple add the ability for a third-party app to **write `HKMedicationDoseEvent` samples for the user's own data**, gated by the *same* explicit per-object (per-medication) authorization model that already governs reads.
>
> **Use case:**
>
> We build PillBreakfast, a watch-first medication tracker for someone who takes roughly a dozen pills per day across maintenance and as-needed regimens, including safety-critical doses (e.g. lithium) that must not be double-taken. All dose logging happens on Apple Watch, one pill per screen, single confirm. The app already *reads* the user's Apple Health medications during onboarding (per-medication read authorization) so the user doesn't have to re-enter them.
>
> Because we cannot *write* dose events, every dose the user logs on the watch is invisible to Apple Health. The user's own Health record — the record their clinician reviews, and the record Apple's own UI presents — is permanently incomplete for any user of a third-party logging app. The two surfaces (Apple Health and the third-party app) can silently disagree about what the user has taken. For a safety-critical medication, an authoritative, reconciled record matters.
>
> **Why this is a natural, privacy-preserving extension:**
>
> 1. It concerns *only the user's own data*. We are not asking to write to anyone else's record or to create medications the user didn't define.
> 2. It would reuse the *existing per-object authorization model*. The user already chooses, per medication, which apps may read. The same picker could grant write. No new consent paradigm.
> 3. The read API already proves the data model and authorization plumbing exist; write is the symmetric capability.
> 4. It directly improves the *user's* outcome: a complete medication-adherence history in Apple Health, contributed by the tool they actually use to log on their wrist.
>
> **Current workaround and its limits:**
>
> Without write access, we maintain our own store and can only *read* Health to avoid double-prompting (detecting doses the user logged in Health via `HKAnchoredObjectQuery`). This is one-directional: we can react to Health, but we can never make the user's watch-logged doses appear in Health. The asymmetry is structural and cannot be solved at the app layer.
>
> **Requested behavior:**
>
> Permit `HKHealthStore.save(_:)` (or an equivalent dose-event write API) for `HKMedicationDoseEvent` from third-party apps, subject to an explicit per-medication *write* authorization grant chosen by the user, mirroring the current per-medication read grant. Apple Health would remain the place medications themselves are defined; we are requesting only the ability to contribute *dose events* the user has logged.
>
> **Impact if granted:**
>
> A single API change would let watch-first medication trackers contribute back to the user's Health record, producing one reconciled source of truth, eliminating dual-source disagreement, and giving clinicians a complete adherence picture without a separate export.
>
> **Steps to reproduce (current limitation):**
>
> 1. Authorize a third-party app to read a medication from Apple Health.
> 2. Attempt to save an `HKMedicationDoseEvent` from the third-party app.
> 3. Observe that the write is not permitted (medication data is read-only for third parties).
>
> **Expected:** with an explicit per-medication write grant, the dose event saves to Apple Health.
>
> **Attachments:** (optional) short screen recording of the watch tap-through logging flow — demo/seeded data only, never real PHI.

## Examples

The archived file `Submission/apple-feedback-medications-write.md` should open with a small header recording the tracking metadata, then the verbatim submission:

```markdown
# Apple Feedback Assistant — HKMedicationDoseEvent write access

- Feedback ID: FB#########
- Filed: 2026-06-07 (Geoff's developer Apple ID)
- Status: Open — passive tracker
- Follow-up cadence: each WWDC + each major HealthKit release
- Related: issue #72, issue #70 (readback workaround), SPEC §3 / §3.4 / §12.6

---

<verbatim submission text from spec §5.5>
```

## Constraints

**Scope fence:** File the request, archive it, record the ID, cross-link it, set a follow-up cadence. **No** code, **no** tests, **no** speculative write-path. **One** focused report — no duplicates, no DTS incident, no forum/social campaign (an optional forum cross-link aside). **No** real PHI in the submission or any attachment (seeded/demo data only). Do not modify the spec files; copy the draft verbatim into the archive. If Apple **grants** it, that spins up a *new* v2 SPEC — out of scope here.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** N/A — this issue ships no code and changes no runtime behavior. The only repo artifact is the archived Markdown submission; the only external artifact is the filed Feedback report. Both apps build exactly as before (the added Markdown must pass the Markdown lint hooks).

## Done-Done
- [ ] An Apple Feedback Assistant enhancement request for third-party `HKMedicationDoseEvent` write access (user-own-data, per-medication authorization) has been **filed**, and the assigned **Feedback ID** (`FBxxxxxxxx`) is recorded in this issue.
- [ ] `Submission/apple-feedback-medications-write.md` is committed, matching the filed text verbatim and including the Feedback ID.
- [ ] SPEC §3 references the Feedback ID so the open request is discoverable from the decision record; issue #70 is cross-linked.
- [ ] A follow-up note/date is recorded and the issue **remains open** as a passive tracker (or is closed with a citable Apple resolution).
- [ ] `pre-commit run --all-files` is clean for the added Markdown.
- [ ] PR (or issue close with link) references `Refs #11` / `Closes #72`. No build/CI gate — this is advocacy, not a code change.

## Labels

`spec-decomposition`, `future-work`, `advocacy`
