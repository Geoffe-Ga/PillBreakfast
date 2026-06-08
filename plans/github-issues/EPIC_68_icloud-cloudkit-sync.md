# Epic — #68: iCloud sync via CloudKit-backed SwiftData

## Epic Summary

Make the existing App-Group SwiftData store **CloudKit-backed** (private database, gated on opt-in + iCloud availability) so a user's regimen and history converge across their non-watch devices and survive device loss. The hard question this creates — what happens to the v1 WatchConnectivity (WC) path — is resolved by the spec: **CloudKit *augments*, it does not replace, WC.** WC remains the authoritative, low-latency, phone-off-tolerant channel for the watch logging ritual; CloudKit handles multi-phone / iPad / new-device convergence and durable backup. **The watch is not a CloudKit peer in this phase.** Coexistence is safe because every merge path is already id-keyed and idempotent (upsert-by-`DoseEvent.id`, archive-never-delete).

This is post-v1 work (SPEC §12.2). All children carry `future-work` so the Ralph picker parks them.

## Scope

**In:**
- Schema-discipline pass: drop `@Attribute(.unique)` from every `id`; confirm relationship optionality / default-empty collections; explicit `VersionedSchema` + `SchemaMigrationPlan` with migration tests.
- Entitlements + container `iCloud.com.creekmasons.pillbreakfast`; conditional `ModelConfiguration` (CloudKit private vs. local-only) gated on availability + opt-in, same store URL.
- Settings iCloud Sync toggle + status + opt-in explainer.
- Reconciliation hardening: assert idempotency where WC and CloudKit overlap (dose upsert, regimen archive-never-delete); conflict policy for ingredient ceilings.
- Privacy nutrition-label delta + in-app disclosure; CloudKit dev→prod schema-promotion runbook step.

**Out:**
- Making the watch a CloudKit peer (WC stays the only phone↔watch link; rationale §5.3).
- Caregiver / `CKShare` shared-zone sharing — that is #69, a different threat model.
- Any public/shared CloudKit database — private only.
- Any change to the watch logging UX.

## Success Criteria

- Regimen + history converge across two phones signed into the same iCloud account.
- The watch continues to receive the regimen and emit doses over WC, unchanged, **including when the phone is off** (no regression).
- A dose seen via both WC and CloudKit produces exactly one row.
- No-iCloud-account devices run fully on the local-only store and can later enable sync without data loss.
- Migration from the current local store is validated on a populated fixture.
- Privacy nutrition label updated; opt-in explainer shipped.
- No anti-bypass violations.

## Child Issues

- [ ] **Skeleton** — `EPIC_68_ISSUE_01_schema-discipline-migration.md`: drop `@Attribute(.unique)` from all `id`s; confirm relationship optionality + default-empty collections; introduce `VersionedSchema` + `SchemaMigrationPlan`; migration tests on a populated fixture. Local-only; no cloud yet — stays green.
- [ ] **Core** — `EPIC_68_ISSUE_02_entitlements-conditional-config.md`: iCloud/CloudKit entitlement + container id + `remote-notification` mode; conditional `ModelConfiguration` (cloud vs. local-only) on the same store URL, gated on availability + opt-in. Defaults off; behaves identically to today when off.
- [ ] **Core** — `EPIC_68_ISSUE_03_settings-toggle-explainer.md`: Settings iCloud Sync toggle + status ("Synced just now" / "Waiting for iCloud" / "iCloud unavailable — using this device only") + first-enable explainer. Monochrome Liquid Glass; no watch UI.
- [ ] **Edges** — `EPIC_68_ISSUE_04_reconciliation-conflict-policy.md`: assert WC↔CloudKit idempotency (dose upsert no-ops duplicates; regimen archive-never-delete); ingredient-ceiling conflict policy (stricter-wins if feasible, else field-LWW); account-switch / no-account / quota fallbacks.
- [ ] **Polish** — `EPIC_68_ISSUE_05_privacy-and-prod-promotion.md`: privacy nutrition-label delta + in-app disclosure (PHI in private iCloud); CloudKit dev→prod schema-promotion step in the release runbook.

## Sequencing Notes

Children are strictly ordered skeleton → config → UI → edges → polish; each child's Context names its predecessor. ISSUE_01 must land and migrate cleanly before any `cloudKitDatabase:` is introduced (ISSUE_02). ISSUE_03 surfaces the toggle the config in ISSUE_02 reads. ISSUE_04 hardens the coexistence guarantees once cloud delivery exists. ISSUE_05 is the release-gating polish. The whole epic is a child of phase-epic **#11** (Future Work Placeholders); the existing issue **#68** is its parent epic. **#69 (caregiver mode) depends on this epic** — `CKShare` needs the CloudKit foundation laid here.

## SPEC Reference

`plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` (full design). SPEC §12.2, §4 (Persistence/Sync rows), §5 (data model), §8.1 (watch-off requirement).

## Labels

`spec-decomposition`, `future-work`, `core`, `concurrency`
