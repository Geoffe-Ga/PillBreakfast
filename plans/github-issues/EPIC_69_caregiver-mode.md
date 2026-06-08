# Epic — #69: Caregiver mode (read-only sharing)

## Epic Summary

Let a user share **read-only regimen and adherence visibility** with a trusted caregiver/partner — "did Geoff take his lithium this morning?" — without exposing edit control and without a server we operate. The recommended path is Apple's CloudKit **`CKShare`** layered on the #68 private-database work: a custom shared record zone holds a **minimal, purpose-built projection** (never the raw model graph), the patient invites a caregiver by Apple ID via `UICloudSharingController`, and the caregiver gains `.readOnly` participant access. Identity, encryption, and revocation are entirely Apple-managed. Consent is **per-surface, per-caregiver, and revocable**; notes/free-text are excluded at the schema level. This is the most PHI-sensitive feature in the backlog — a rigorous threat model treats the caregiver relationship as potentially adversarial.

This is post-v1, post-#68 work (SPEC §12.3) and is genuinely speculative ("Freedom?"). **Every child carries `v2`** (and `future-work`) so the Ralph picker parks them, and the feature is built only if validated.

## Scope

**In:**
- Purpose-built `CaregiverRegimenProjection` / `CaregiverAdherenceProjection` record types derived from existing DTOs; data-minimization enforced at the schema level (no notes ever).
- Custom shared CloudKit zone + projection write/refresh from the patient device.
- Per-surface, per-caregiver consent model (regimen / adherence / PRN totals) + patient-side audit log.
- `CKShare` create/invite via `UICloudSharingController`; `.readOnly` participant.
- Caregiver read-only viewer surface (form factor TBD at grooming).
- Revocation + account-switch + "last updated" staleness handling.
- Privacy nutrition-label delta + consent screen + legal/compliance sign-off gate.

**Out:**
- Caregiver **write** access (no remote logging, no remote regimen edits).
- Caregiver notifications / nagging to the patient.
- Multi-patient "dashboard" / professional fan-out (one patient → one or few personal caregivers).
- Any operated backend, accounts system, or our own auth.
- Anything on the watch surface; `LogSource` is **not** extended with a `.caregiver` case.

## Success Criteria

- A patient can invite a caregiver, choose exactly which surfaces (regimen / adherence / PRN) are shared, and see a plain-language summary of what the caregiver can view.
- The caregiver sees a **read-only** view; notes/free text are never present; no edit or logging affordances exist.
- Revocation immediately removes caregiver access and deletes the shared projection records.
- No server we operate is involved; identity/auth/encryption are entirely Apple-managed.
- The watch is never a participant; the logging ritual is unaffected.
- Privacy nutrition label updated; consent screen + audit log shipped; compliance review signed off.
- No anti-bypass violations.

## Child Issues

- [ ] **Skeleton** — `EPIC_69_ISSUE_01_projection-types-gate.md`: confirm #68 shipped + stable; define `CaregiverRegimenProjection` / `CaregiverAdherenceProjection` value types from existing DTOs; unit-test data minimization (notes/free-text fields literally don't exist on the projection). No CloudKit, no sharing yet — stays green.
- [ ] **Core** — `EPIC_69_ISSUE_02_shared-zone-projection-write.md`: custom shared CloudKit zone; write/refresh projection records from the patient device (built off #68's container). Gated/off by default.
- [ ] **Core** — `EPIC_69_ISSUE_03_consent-model-audit.md`: per-surface, per-caregiver consent toggles (regimen / adherence / PRN) that actually gate which projection records are written; patient-side audit log.
- [ ] **Core** — `EPIC_69_ISSUE_04_ckshare-invite-viewer.md`: `CKShare` create/invite via `UICloudSharingController` (`.readOnly` participant); caregiver read-only viewer surface (form factor per grooming) clearly labeled "read only," no logging/edit affordances.
- [ ] **Edges** — `EPIC_69_ISSUE_05_revocation-accountswitch-staleness.md`: revocation tears down the `CKShare` + deletes projection records; account-switch re-scoping (never silent re-point); "last updated" staleness UI; decline/pending states; multi-caregiver independence.
- [ ] **Polish** — `EPIC_69_ISSUE_06_privacy-consent-compliance.md`: privacy nutrition-label delta; plain-language consent screen at invite time; "can't un-see" honest disclosure; legal/compliance review sign-off gate.

## Sequencing Notes

Children are strictly ordered skeleton → zone/write → consent → share/viewer → edges → polish; each child's Context names its predecessor. **ISSUE_01 must verify #68 (CloudKit private DB) shipped and is stable before anything else** — `CKShare` needs that foundation; if #68 is descoped, the only honest fallback is the existing PDF export (not live visibility) and this epic is blocked. ISSUE_03 (consent) must gate ISSUE_02's writes before ISSUE_04 exposes a share. ISSUE_06's compliance sign-off is a **gating prerequisite before this ships**, not a formality. The whole epic is a child of phase-epic **#11** (Future Work Placeholders); the existing issue **#69** is its parent epic; it **depends on epic #68**.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` (full design). SPEC §12.3, §3 (HealthKit constraint — unaffected), §5 (DTOs as projection source), §6.3 (Settings). Depends on `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `core`, `concurrency`
