# SPEC — Issue #72: File Apple Feedback Assistant Request for `HKMedicationDoseEvent` Write Access

| Field | Value |
|---|---|
| Issue | #72 |
| Phase | Future Work (SPEC §12.6) |
| Labels | `spec-decomposition`, `future-work`, `needs-spec`, `advocacy` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #11 |
| Related | #70 (readback enrichment — the read-only workaround this would obviate half of), SPEC §3 (the constraint being challenged) |

> **Note:** This is a process / advocacy spec, not a code task. Code-heavy sections (Detailed
> Design framework contracts, schema/sync deltas, concurrency, automated testing) are intentionally
> reframed around the *submission* rather than an implementation. The deliverable is a filed Apple
> Feedback Assistant report, a tracked feedback ID, and an archived copy of the submission in the
> repository.

---

## 1. Summary

The single most consequential constraint on PillBreakfast's architecture is that **third-party apps
cannot write to Apple Health Medications** — `HKMedicationDoseEvent` is read-only for third parties,
confirmed by Apple DTS (SPEC §3.2). This forces PillBreakfast to own its entire data layer and makes
the two surfaces (PillBreakfast + Apple Health) permanently capable of disagreeing about what the
user has taken. This issue files an Apple Feedback Assistant request asking Apple to allow a
third-party app to write dose events **for the user's own data, with explicit user authorization** —
the same per-object authorization model that already governs reads. A single such API change would
let PillBreakfast contribute its watch-logged doses back to Health, collapsing the dual-source
problem and dramatically simplifying a v2 architecture (SPEC §3.4). The deliverable is a filed
feedback report, its ID, and an archived copy of the submission committed to the repo.

---

## 2. Problem Statement / Motivation

**The constraint and its cost.** Because PillBreakfast cannot write to Health:
- The user's *complete* medication-adherence picture is split across two apps that cannot reconcile.
  A clinician pulling the patient's Health record sees nothing PillBreakfast logged.
- Issue #70 (readback enrichment) exists *only* to paper over half of this — it can read Health to
  avoid double-prompting, but it can never make PillBreakfast's watch-logged doses appear in Health.
  The asymmetry is structural and unfixable without an Apple change.
- v2 cannot consider Health as a shared system-of-record even where that would be the cleaner design
  (SPEC §3.4 "Health as authority" was rejected partly because of this).

**Why this is worth filing despite long odds.** The feedback assistant request is cheap, the
upside is architecturally large, and Apple's read API already proves the per-medication
authorization model works — write access for the user's own data is a natural, privacy-preserving
extension, not a new paradigm. Even a "won't fix" closes the question authoritatively (better than
the current forum-quote-from-DTS evidence). Keeping the issue alive signals the platform gap.

**Why deferred.** It is non-blocking advocacy with an indefinite response timeline; it is filed
once and then tracked passively. It belongs in future-work because nothing in v1 depends on its
outcome — but it should be filed *early* so any eventual Apple action lands before v2 design.

---

## 3. Goals and Non-Goals

**Goals**
- File a single, well-argued Apple Feedback Assistant request for third-party **write** access to
  `HKMedicationDoseEvent`, scoped to the user's own data under explicit per-object authorization.
- Attach a concrete, real-world use case (PillBreakfast's watch-first logging) and the technical +
  UX justification.
- Record the resulting Feedback ID and commit an archived copy of the submission to
  `Submission/apple-feedback-medications-write.md`.
- Establish a lightweight follow-up / tracking cadence and link the request to #70 and the SPEC §3
  decision record.

**Non-Goals**
- Writing any code, or building any speculative write-path that assumes the request is granted.
  (If granted, that is a *future* SPEC tied to v2.)
- Filing duplicate or multiple reports (one focused report is more effective than several).
- Lobbying beyond the official Feedback Assistant channel (no DTS tickets, no forum campaigns as
  part of *this* issue — though a forum cross-link is fine).
- Committing to a v2 architecture contingent on the outcome.

---

## 4. Background and Current State

### 4.1 The constraint (quoted)

SPEC §3.2:

> "Third-party apps cannot write to HealthKit Medications. This is confirmed directly by Apple DTS:
> 'Medication data is read-only in HealthKit.' — Apple Developer Forums, 2025. Medications and dose
> events must be authored in the Health app itself. Apps can consume the data but cannot contribute."

CLAUDE.md, "Critical Architecture Constraint":

> "Third-party apps cannot write to Apple Health Medications. `HKMedicationDoseEvent` is read-only
> for third-party apps. Confirmed by Apple DTS. ... PillBreakfast owns its own SwiftData store as
> the source of truth."

SPEC §12.6 (this charter):

> "Negotiating with Apple for write access. Worth filing a feedback request asking for
> `HKMedicationDoseEvent` write capability for the user's own data. Long shot, but a single API
> change would dramatically simplify v2."

### 4.2 What the granted request would change (tie-back to §3.4)

SPEC §3.4's alternatives table rejected "Health as authority + our app as viewer" and "Pure Health
piggyback" *because* the read-only/write-impossible constraint breaks the core watch UX and blocks
PRN running totals. Write access would not, by itself, make Health the authority — but it would
unlock a **dual-write / contribute-back** posture for v2:

| v1 reality (read-only) | If write access granted |
|---|---|
| PillBreakfast store is the only record of watch-logged doses. | PillBreakfast can mirror each `.taken` dose into Health, so the system Health record is complete. |
| #70 can only *read* Health to suppress prompts (one-directional). | The symmetric direction becomes possible: a PillBreakfast log can quiet Health's own reminder. |
| Clinician's Health export omits PillBreakfast data. | Clinician sees a unified record without PillBreakfast's PDF export being the only source. |
| Two sources can silently disagree. | One reconciled source of truth is achievable. |

This is the concrete v2 simplification the request targets, and exactly why it's worth filing.

### 4.3 Evidence already on hand

- The DTS confirmation (forum-quoted) is the *current* state of knowledge. A formal Feedback request
  produces an authoritative, citable Apple response that supersedes a forum quote.
- The shipped read-only import flow (`PillBreakfast/HealthKitImport/`) is proof that PillBreakfast is
  a legitimate, well-behaved Health consumer already using the *read* side of the very API — strong
  context to attach.

---

## 5. The Feedback-Submission Plan

### 5.1 Channel and classification

- **Channel:** Apple Feedback Assistant (`feedbackassistant.apple.com` or the macOS/iOS app), the
  official enhancement-request path that routes to the HealthKit engineering team.
- **Type:** Suggestion / API enhancement request (not a bug).
- **Area:** HealthKit (Medications).
- **Audience:** filed under Geoff's developer Apple ID so it is linkable to the developer account.

### 5.2 What to attach as evidence / use case

1. A one-paragraph description of PillBreakfast (watch-first medication tracker, ~12 pills/day,
   safety-critical lithium) — the *real* use case grounds the request.
2. The exact asymmetry: the app already reads Health medications (cite the Phase 6 import) but cannot
   write the doses the user logs on the watch, so the system Health record is permanently incomplete.
3. The privacy framing: request is **for the user's own data, under the same explicit per-object
   authorization model that already gates reads** — no new privacy surface, the user opts in
   per-medication exactly as today.
4. The DTS confirmation reference (that read-only is current behavior), so the engineer reading it
   knows this is a deliberate enhancement ask, not a misunderstanding.
5. (Optional) a short screen recording of the watch tap-through log, to make concrete what data would
   be contributed.

### 5.3 Follow-up and tracking

- Record the assigned **Feedback ID** (`FBxxxxxxxx`) in this issue and in
  `Submission/apple-feedback-medications-write.md`.
- Re-check status at each WWDC and each major HealthKit release; note any Apple reply in the issue.
- Cross-link the Feedback ID from SPEC §3 (the decision record) so a future contributor evaluating a
  v2 dual-write design finds the outstanding request immediately.
- Keep the issue **open** (it's a passive tracker) until Apple resolves it or the team decides the
  v2 direction no longer needs it.

### 5.4 Deliverables (issue done-criteria, restating the issue's Output Format)

- [ ] The Feedback Assistant ID.
- [ ] A copy of the submitted request committed at `Submission/apple-feedback-medications-write.md`.

### 5.5 Ready-to-File Feedback Draft

The following is the complete text to paste into Feedback Assistant and to archive verbatim in
`Submission/apple-feedback-medications-write.md`.

> **Title:** Allow third-party apps to write `HKMedicationDoseEvent` for the user's own data, under
> per-medication authorization
>
> **Area:** HealthKit — Medications
>
> **Type:** API enhancement / suggestion
>
> **Description:**
>
> The HealthKit Medications API introduced in iOS 26 exposes `HKUserAnnotatedMedication` and
> `HKMedicationDoseEvent` as **read-only** for third-party apps (confirmed by Apple DTS:
> "Medication data is read-only in HealthKit"). Apps can consume the user's medications and dose
> events but cannot contribute. We request that Apple add the ability for a third-party app to
> **write `HKMedicationDoseEvent` samples for the user's own data**, gated by the *same* explicit
> per-object (per-medication) authorization model that already governs reads.
>
> **Use case:**
>
> We build PillBreakfast, a watch-first medication tracker for someone who takes roughly a dozen
> pills per day across maintenance and as-needed regimens, including safety-critical doses (e.g.
> lithium) that must not be double-taken. All dose logging happens on Apple Watch, one pill per
> screen, single confirm. The app already *reads* the user's Apple Health medications during
> onboarding (per-medication read authorization) so the user doesn't have to re-enter them.
>
> Because we cannot *write* dose events, every dose the user logs on the watch is invisible to Apple
> Health. The user's own Health record — the record their clinician reviews, and the record Apple's
> own UI presents — is permanently incomplete for any user of a third-party logging app. The two
> surfaces (Apple Health and the third-party app) can silently disagree about what the user has
> taken. For a safety-critical medication, an authoritative, reconciled record matters.
>
> **Why this is a natural, privacy-preserving extension:**
>
> 1. It concerns *only the user's own data*. We are not asking to write to anyone else's record or to
>    create medications the user didn't define.
> 2. It would reuse the *existing per-object authorization model*. The user already chooses, per
>    medication, which apps may read. The same picker could grant write. No new consent paradigm.
> 3. The read API already proves the data model and authorization plumbing exist; write is the
>    symmetric capability.
> 4. It directly improves the *user's* outcome: a complete medication-adherence history in Apple
>    Health, contributed by the tool they actually use to log on their wrist.
>
> **Current workaround and its limits:**
>
> Without write access, we maintain our own store and can only *read* Health to avoid double-prompting
> (detecting doses the user logged in Health via `HKAnchoredObjectQuery`). This is one-directional:
> we can react to Health, but we can never make the user's watch-logged doses appear in Health. The
> asymmetry is structural and cannot be solved at the app layer.
>
> **Requested behavior:**
>
> Permit `HKHealthStore.save(_:)` (or an equivalent dose-event write API) for `HKMedicationDoseEvent`
> from third-party apps, subject to an explicit per-medication *write* authorization grant chosen by
> the user, mirroring the current per-medication read grant. Apple Health would remain the place
> medications themselves are defined; we are requesting only the ability to contribute *dose events*
> the user has logged.
>
> **Impact if granted:**
>
> A single API change would let watch-first medication trackers contribute back to the user's Health
> record, producing one reconciled source of truth, eliminating dual-source disagreement, and
> giving clinicians a complete adherence picture without a separate export.
>
> **Steps to reproduce (current limitation):**
>
> 1. Authorize a third-party app to read a medication from Apple Health.
> 2. Attempt to save an `HKMedicationDoseEvent` from the third-party app.
> 3. Observe that the write is not permitted (medication data is read-only for third parties).
>
> **Expected:** with an explicit per-medication write grant, the dose event saves to Apple Health.
>
> **Attachments:** (optional) short screen recording of the watch tap-through logging flow.

---

## 6. Alternatives Considered

| Option | Verdict |
|---|---|
| File one focused Feedback Assistant enhancement request (chosen) | ✅ Official channel that reaches HealthKit engineering; produces a citable ID and authoritative response. |
| Open a DTS technical support incident instead | ❌ DTS answers *how the API behaves today* (already answered: read-only). It is not the enhancement-request channel. |
| File multiple reports / repeated reports | ❌ Dilutes signal; one well-argued report is more effective. |
| Public forum / social campaign | ⚠️ Optional cross-link only; not a substitute for the formal request, and out of scope for this issue. |
| Don't file; design v2 around read-only permanently | ⚠️ The current default. But filing is cheap and keeps the architecturally-large option open. |
| Build a speculative write-path now in case it's granted | ❌ Pure waste until/unless Apple acts; explicitly a non-goal. |

---

## 7. UX and Visual Design

Not applicable — there is no in-app UX in this issue. The *only* user-facing artifact is the
hypothetical future per-medication **write** authorization picker, which (if Apple grants the
request) would mirror the existing read picker. No PillBreakfast UI changes ship as part of #72.

---

## 8. Edge Cases and Failure Modes (of the process)

- **Apple closes as "won't fix" or duplicate.** Record the resolution in the issue; the SPEC §3
  decision stands and #70 remains the best available mitigation. The issue can then be closed with a
  clear citable answer (an improvement over the current forum-quote evidence).
- **No response (most likely).** The issue stays open as a passive tracker; revisit at WWDC cadence.
- **Apple requests more detail.** Respond via the same Feedback thread; update the archived copy if
  the submission is amended.
- **Apple grants it.** Out of scope here — spin up a *new* v2 SPEC for the dual-write/contribute-back
  architecture, referencing this Feedback ID and SPEC §3.4.
- **Account/access changes** (the filing developer account changes): the archived
  `Submission/...md` + Feedback ID in the repo keep the record durable regardless.

---

## 9. Privacy, Security and Compliance

The request itself transmits no PHI — it is a written enhancement description plus an optional
generic screen recording (which should show *fixture* data, never real medication history). The
*requested capability* is explicitly framed to be privacy-preserving: user-own-data only, under
explicit per-medication authorization identical to the existing read model. The submission must not
attach any real dose history or identifiable health data. If a screen recording is included, it must
use seeded/demo medications only.

---

## 10. Testing / Verification Strategy

No automated tests (not a code change). Verification is process-based:
- The Feedback Assistant report is submitted and an `FBxxxxxxxx` ID is returned.
- `Submission/apple-feedback-medications-write.md` exists in the repo and matches the submitted text
  verbatim (including the Feedback ID once assigned).
- The issue body records the Feedback ID and a follow-up date.
- SPEC §3 is cross-linked to the Feedback ID (so the request is discoverable from the decision record).
- `pre-commit run --all-files` is clean for the added Markdown file (the only repo change).

---

## 11. Risks and Open Questions

- **Low probability of action.** Acknowledged up front (SPEC §12.6: "Long shot"). The expected value
  is still positive given the near-zero cost.
- **Exact write API shape Apple might offer is unknown.** The draft requests `HKHealthStore.save(_:)`
  semantics but explicitly defers the precise API to Apple — we are requesting a capability, not
  dictating a signature.
- **Whether to include a screen recording.** Adds concreteness but must avoid any real PHI; use demo
  data only. **Open.**
- **Cadence of follow-up.** Proposed: every WWDC + major HealthKit release. **Confirm.**
- **Who files it.** Must be a real Apple developer account (Geoff's). This is the one step a Ralph
  loop cannot perform autonomously — it requires a human to submit through Feedback Assistant. The
  repo deliverable (archived submission + recorded ID) is the trackable artifact.

---

## 12. Decomposition Hints (post-v1 child tasks)

1. **#72a — Finalize submission text.** Adapt §5.5 draft, decide on the optional screen recording.
2. **#72b — File via Feedback Assistant** (human step) and capture `FBxxxxxxxx`.
3. **#72c — Commit `Submission/apple-feedback-medications-write.md`** with the verbatim text + ID;
   cross-link from SPEC §3 and issue #70.
4. **#72d — Establish follow-up tracker** (WWDC-cadence check; note any Apple reply on the issue).

(These are small and sequential; could ship as a single PR + a human filing step rather than four
issues, per the issue's own "single PR or issue close with a link" output format.)

---

## 13. Acceptance Criteria / Done-Done

- [ ] An Apple Feedback Assistant enhancement request for third-party `HKMedicationDoseEvent` write
      access (user-own-data, per-medication authorization) has been **filed**.
- [ ] The assigned **Feedback ID** (`FBxxxxxxxx`) is recorded in issue #72.
- [ ] `Submission/apple-feedback-medications-write.md` is committed, matching the filed text verbatim
      and including the Feedback ID.
- [ ] SPEC §3 references the Feedback ID so the open request is discoverable from the decision record.
- [ ] Issue #72 carries a follow-up note/date and remains open as a passive tracker (or is closed
      with a citable Apple resolution).
- [ ] `pre-commit run --all-files` clean for the added Markdown.
- [ ] PR (or issue close with link) references `Refs #11` / `Closes #72`.

---

## 14. References

- `plans/SPEC.md` §3 (the HealthKit constraint and decision), §3.2 (read-only / iOS-only, DTS quote),
  §3.4 (alternatives — what write access would unlock), §12.6 (this charter).
- `CLAUDE.md` — "Critical Architecture Constraint: HealthKit Is Read-Only."
- Code context (legitimate-consumer evidence to attach): `PillBreakfast/HealthKitImport/` (the shipped
  read-only import flow), `Shared/Models/Medication.swift` (`healthKitConceptID`).
- Related issues: #70 (readback enrichment — the read-only workaround this request would render
  half-redundant).
- Apple: Feedback Assistant (`feedbackassistant.apple.com`); HealthKit Medications API
  (`HKMedicationDoseEvent`, `HKUserAnnotatedMedication`); per-object authorization (WWDC 2025
  "Meet the HealthKit Medications API").
