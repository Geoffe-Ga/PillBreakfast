# SPEC — Caregiver Mode

| | |
|---|---|
| **Issue** | #69 |
| **Classification** | Future Work (SPEC §12.3) |
| **Labels** | `spec-decomposition`, `future-work`, `needs-spec`, `v2` |
| **Status** | Draft |
| **Date** | 2026-06-07 |
| **Related** | Epic #11; depends on #68 (CloudKit) as a prerequisite for the recommended approach |

---

## 1. Summary

Let a user share **read-only regimen and adherence visibility** with a trusted caregiver/partner — e.g. "did Geoff take his lithium this morning?" — without exposing edit control or building a server we operate. This spec evaluates the architecture honestly: it requires either Apple's CloudKit sharing (`CKShare` over a shared zone) or a real backend, carries a serious PHI threat model, and is correctly deferred (`v2`). The recommended path, **if built, is CloudKit `CKShare`** layered on the #68 private-database work — no operated backend, Apple-managed auth and encryption. A bespoke backend is documented as the alternative and rejected for v2.

## 2. Problem Statement / Motivation

For a safety-critical regimen (lithium that must not be doubled or skipped), a partner being able to *see* adherence — without nagging notifications to the patient, without taking control — has real care value. SPEC §12.3 flags it precisely and honestly:

> **Caregiver mode.** Sharing regimen visibility with a partner (Freedom?) — out of scope; would require a real backend.

**Why deferred (and `v2`):** this is the single most sensitive feature in the product. It moves PHI *out of one person's control and into another's*, which demands a real consent model, a defensible threat model, revocation, and an auth story. None of that should be rushed, and all of it depends on the cloud foundation (#68) existing first. The issue itself is labeled `needs-spec` with "requires a real backend" as the blocking open question — this spec's job is to resolve *whether* a backend is actually required (it isn't, if we use `CKShare`) and to specify the consent/threat model rigorously.

## 3. Goals & Non-Goals

**Goals (for the eventual feature)**
- A patient can invite a named caregiver to view a **defined, read-only** subset of their data.
- Explicit, revocable, per-share consent — the patient is always in control.
- No server we operate; Apple-managed identity, encryption, and access control.
- A threat model that treats the data as PHI and the caregiver relationship as potentially adversarial (e.g. a relationship that ends).
- Zero impact on the watch logging ritual.

**Non-Goals**
- **Not** caregiver *write* access (no remote logging, no remote regimen edits) in v2. Read-only.
- **Not** caregiver notifications/nagging to the patient.
- **Not** multi-patient "dashboard" / professional-caregiver fan-out (one patient → one or few personal caregivers only).
- **Not** an operated backend, accounts system, or our own auth.
- **Not** anything on the watch surface.

## 4. Background & Current State

- There is **no sharing, no backend, and no multi-user concept** in the codebase today. The store is single-user, App-Group-local (`PersistenceController`), synced only phone↔watch via WC. `LogSource` is `.watch | .iphone` — there is no notion of a remote actor.
- The data a caregiver would view already exists as clean value types suitable for projection: `RegimenSnapshot` / `MedicationDTO` / `ScheduledDoseDTO` (regimen) and `DoseEventDTO` / `LoggedIngredientAmount` (adherence). These are already `Codable, Sendable` and already cross trust/serialization boundaries — they are the natural read-only projection surface for a share.
- **#68 (CloudKit private DB) is the prerequisite.** `CKShare` operates on records in a CloudKit zone; without the store being CloudKit-backed there is nothing to share. So #69 is sequenced *after* #68.
- HealthKit constraint (SPEC §3, CLAUDE.md) is unaffected — Health remains read-only/iOS-only and is never the authority; caregiver mode shares *PillBreakfast's own* store, not Health.

**SPEC §12.3 quoted:** *"Caregiver mode. Sharing regimen visibility with a partner (Freedom?) — out of scope; would require a real backend."*

## 5. Detailed Design

### 5.1 Recommended architecture — CloudKit `CKShare` (no operated backend)

Build on #68. Move the shareable subset into a **dedicated CloudKit record zone** (a custom zone is required for `CKShare`; the default zone can't be shared). The patient creates a `CKShare` over that zone and invites a caregiver by their Apple ID (via the standard `UICloudSharingController`). The caregiver accepts on their own device and gains **read-only** participant access to the shared records in *their* CloudKit view of the patient's shared zone.

Key properties this buys for free (the reason it beats a backend):
- **Identity & auth:** Apple ID, handled by `UICloudSharingController` + the share-acceptance flow. We write zero auth code.
- **Encryption & transport:** Apple-managed, same guarantees as the #68 private DB.
- **Revocation:** the patient removes the participant or deletes the `CKShare`; access ends. First-class, patient-controlled.
- **No PHI on any server we run** — there is no server we run.

**What's shared (read-only projection):** rather than sharing the *live* model graph, share a **purpose-built, minimal projection** so the caregiver sees only what's consented:
- A `CaregiverRegimenProjection` record: medication display names + schedules (no notes, no raw ingredient library details beyond what's needed).
- A `CaregiverAdherenceProjection` record stream: per-day "taken / skipped / pending" status per scheduled dose, derived from `DoseEvent`. **Granularity is a consent choice** (see §5.4).

These projections are produced from the existing DTOs (`MedicationDTO`, `DoseEventDTO`) on the patient's device and written to the shared zone. The caregiver app renders them read-only. The patient's **real** store stays in the private (unshared) zone — sharing never exposes the full graph, only the projection.

### 5.2 Why a projection, not the raw shared zone

If we simply put `Medication`/`DoseEvent` records into a shared zone, the caregiver gets whatever fields those records carry (including `notes`, which may be intimate). A projection enforces **data minimization** at the schema level: the caregiver app literally cannot request fields that aren't in the projection record. This is the correct posture for PHI and makes the consent toggles (§5.4) enforceable rather than cosmetic.

### 5.3 Trust direction & write protection

`CKShare` participants are added with `.readOnly` permission. The caregiver cannot write to the shared zone. Even so, the patient's device treats inbound data from any source as untrusted; since the caregiver is read-only there is no inbound path. The watch is never a participant and never sees the share. `LogSource` is **not** extended with a `.caregiver` case — caregivers don't log.

### 5.4 Consent model (the heart of the feature)

Per the issue's explicit open question ("which surfaces are shared — regimen only? dose events? PRN totals?"), consent is **granular and explicit**:

| Surface | Default | Notes |
|---|---|---|
| Regimen (med names + schedule) | opt-in | The minimum useful share. |
| Adherence status (taken/skipped/pending per scheduled dose) | opt-in, separate toggle | The high-value, higher-sensitivity surface. |
| PRN running totals (e.g. acetaminophen mg today) | opt-in, separate toggle | Reveals as-needed behavior; most sensitive; off by default. |
| Notes / free text | **never shared** | Excluded at the projection-schema level. |
| Raw `DoseEvent` timestamps to the minute | configurable | Option to share day-level status only, not exact times. |

Consent is **per-caregiver** and **revocable at any time**, with a clear in-app summary of "what this person can see." Revocation tears down the `CKShare` and deletes the projection records from the shared zone.

### 5.5 Concurrency / isolation

Projection generation reuses the established MainActor-collect → Sendable-value-type pattern (as in `RegimenSnapshot.from` and `PDFExporter.collectBlocks`). Projection records are built from `Sendable` DTOs; CloudKit operations are async. No `@unchecked Sendable`.

## 6. Alternatives Considered

| Decision | Options | Verdict |
|---|---|---|
| Sharing substrate | CloudKit `CKShare` (recommended) / operated backend + accounts / iMessage/export only | **`CKShare`.** No operated server, Apple-managed identity/encryption/revocation. Backend is a liability (PHI custody, auth, ops, compliance) we don't need. Export-only (e.g. the existing PDF) is the zero-build fallback but isn't *live* visibility. |
| Shared content | Minimal projection records (recommended) / share raw model zone | **Projection.** Enforces data minimization at the schema level; raw-zone sharing leaks `notes` and over-shares. |
| Caregiver capability | Read-only (recommended) / read-write | **Read-only.** Write access multiplies the threat model (remote logging, coercion) for marginal value; deferred indefinitely. |
| Identity | Apple ID via `CKShare` (recommended) / our own accounts | **Apple ID.** We never want to be a PHI identity provider. |
| Prerequisite | After #68 (recommended) / standalone backend | **After #68.** `CKShare` needs the CloudKit foundation; reuses it. |
| Granularity | Per-surface consent toggles (recommended) / all-or-nothing | **Per-surface.** PHI sensitivity differs sharply across regimen / adherence / PRN. |

## 7. UX & Visual Design

- iPhone Settings (SPEC §6.3) gains a **Caregivers** section: list of current shares ("Freedom — can see regimen + adherence"), an **Invite caregiver** action (`UICloudSharingController`), per-caregiver consent toggles (§5.4), and a prominent **Stop sharing** / revoke.
- An explicit, plain-language consent screen at invite time: exactly what the person will see, that they can be removed anytime, that this is medical data.
- **Caregiver-side view** (could be the same app in a "viewing someone's regimen" mode, or a lightweight read-only surface): read-only, monochrome Liquid Glass, clearly labeled "Viewing Geoff's regimen — read only." **No logging controls, no edit controls.**
- **No watch UI.** The watch never participates.
- **Color discipline preserved** — no accent color introduced; amber stays reserved for high-risk press-and-hold on the patient's watch.

## 8. Edge Cases & Failure Modes

- **Caregiver has no iCloud account:** `CKShare` invite requires it; surface a clear prerequisite message.
- **Share acceptance declined / pending:** patient sees "invited, not yet accepted."
- **Relationship ends / revocation:** patient revokes → projection records deleted from shared zone → caregiver loses access immediately. **No residual cache guarantee** is something to message honestly (a caregiver could have screenshotted; we can't prevent that, and we say so).
- **Account switch on either side:** re-scope or invalidate the share; never silently re-point a share to a different Apple ID.
- **Stale projection:** if the patient is offline, the caregiver sees the last-synced projection with a "last updated" timestamp — never a false "all taken."
- **Patient deletes the app / disables #68 CloudKit:** all shares collapse; document this dependency.
- **Multiple caregivers:** supported; each is a separate participant with independent consent and revocation.

## 9. Privacy, Security & Compliance

This is the **highest-stakes section in the entire backlog.**
- **PHI leaving the patient's sole control** is the defining risk. Mitigations: read-only, minimal projection (no notes, no free text), per-surface explicit consent, first-class revocation, Apple-managed encryption/identity, no operated server, no analytics.
- **Threat model includes an adversarial ex-caregiver:** revocation must be immediate and total within CloudKit's control; we honestly disclose that already-seen data can't be un-seen.
- **No third-party processors.** CloudKit only.
- **Privacy nutrition label** must disclose sharing of health data with other users when the feature is enabled.
- **Consent is logged** (patient-side audit: "you started sharing adherence with Freedom on <date>") so the patient can review their own sharing history.
- Legal/compliance review is a gating prerequisite before this ships — flagged here, not hand-waved.

## 10. Testing Strategy

- Projection generation: notes/free-text **never** appear in any projection record (assert at the schema level — the field doesn't exist on the projection type).
- Consent toggles actually gate which projection records are written (regimen-only share contains no adherence/PRN records).
- Revocation deletes shared-zone projection records and the `CKShare`.
- Read-only enforcement: caregiver participant is `.readOnly`; write attempts are rejected.
- Account-switch and decline/pending states render correctly.
- Watch is never a participant (no code path adds it).
- CloudKit-dependent tests gated for headless CI; consent/projection logic unit-tested without a live share.
- No anti-bypass violations.

## 11. Risks & Open Questions

- **Compliance/legal posture** for sharing PHI between consumers — needs review before build; may constrain copy and defaults.
- **`CKShare` UX maturity** for read-only, field-minimized shares — validate `UICloudSharingController` supports the desired permission/granularity, else fall back to a custom invite over the share metadata.
- **Caregiver-app form factor** — same binary in a viewer mode vs. a separate lightweight target — open for grooming.
- **"Can't un-see" disclosure wording** — get right with privacy review.
- **Dependency on #68** — if #68 is descoped, the only honest fallback is export-based sharing (the existing PDF), which is *not* live visibility; document that this feature is genuinely blocked without CloudKit.
- **Whether v2 even ships this** — the SPEC keeps it speculative ("Freedom?"); this spec exists so it can be decomposed *if* validated, not as a commitment.

## 12. Decomposition Hints (post-v1, post-#68, tracer-code order)

1. **Prerequisite gate:** confirm #68 (CloudKit private DB) shipped and stable.
2. Define projection record types (`CaregiverRegimenProjection`, `CaregiverAdherenceProjection`) from existing DTOs; unit-test data minimization (no notes ever).
3. Custom shared CloudKit zone + projection write/refresh from the patient device.
4. Consent model + per-surface toggles + patient-side audit log.
5. `CKShare` create/invite via `UICloudSharingController`; read-only participant.
6. Caregiver read-only viewer surface (form factor TBD).
7. Revocation + account-switch handling + "last updated" staleness UI.
8. Privacy nutrition label + consent screen + legal/compliance review sign-off.

## 13. Acceptance Criteria / Done-Done

- A patient can invite a caregiver, choose exactly which surfaces (regimen / adherence / PRN) are shared, and see a plain-language summary of what the caregiver can view.
- The caregiver sees a **read-only** view; notes/free text are never present; no edit or logging affordances exist.
- Revocation immediately removes caregiver access and deletes the shared projection records.
- No server we operate is involved; identity/auth/encryption are entirely Apple-managed.
- The watch is never a participant; the logging ritual is unaffected.
- Privacy nutrition label updated; consent screen + audit log shipped; compliance review signed off.
- No anti-bypass violations.

## 14. References

- `plans/SPEC.md` §12.3, §3 (HealthKit constraint — unaffected), §5 (data model / DTOs as projection source), §6.3 (Settings).
- Depends on: #68 (CloudKit-backed SwiftData) — `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md`.
- Code: `Shared/Sync/RegimenSnapshot.swift` (`MedicationDTO`/`ScheduledDoseDTO`), `Shared/Sync/DoseEventBatchDTO.swift` (`DoseEventDTO`), `Shared/Models/LoggedIngredientAmount.swift`, `Shared/Models/Enums.swift` (`LogSource` — deliberately *not* extended), `Shared/Persistence/PersistenceController.swift`.
- Apple: CloudKit `CKShare` / `UICloudSharingController` / custom record zones / participant permissions.
- CLAUDE.md: PHI sensitivity, watch-never-on-iPhone-logging discipline, color discipline.
- Issues: #69 (`v2`), epic #11.
