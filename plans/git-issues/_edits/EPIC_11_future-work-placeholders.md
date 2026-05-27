# EPIC 11 — Future Work Placeholders (SPEC §12)

## Epic Summary

A parking-lot epic for SPEC §12 items that are intentionally out of scope for v1. Each child issue is a placeholder marked `needs-spec`; nothing in this epic is ready to ship. Filing them upfront prevents the ideas from disappearing into Slack history and gives the backlog a single home for "v1.1 candidates" the user can groom later.

## Scope

**In scope:**

- One placeholder issue per item in SPEC §12, labeled `needs-spec`.
- Each placeholder issue links back to the SPEC §12 paragraph that defines it and lists the open questions that must be resolved before the issue is actionable.
- No implementation work and no Done-Done block — these are not ready to pick up.

**Out of scope:**

- Anything actually buildable. The moment an item is groomed into a buildable shape, it should be re-filed as a new epic (or as a child of an existing v1 epic if it's a small enough delta) and this placeholder closed as a duplicate of the new issue.

## Critical Architecture (forwarded so groomers see it)

- Pill thumbnails (item 1) add **one nullable field on `Medication`** (`imageAssetID: UUID?`) and use `WCSession.transferFile` for the watch sync. Schema migration is trivial. The watch must never hit the network for images.
- iCloud sync (item 2) implies CloudKit-backed SwiftData; the schema must remain compatible.
- Caregiver mode (item 3) would require a real backend — large, out of scope until v2.
- Health dose readback (item 4) uses `HKAnchoredObjectQuery`. **Still iOS-only, still read-only.** SPEC §3 constraints carry forward forever.
- Action Button binding (item 5) is a single `AppIntent` plus configuration; trivial once it's prioritized.
- Apple feedback request (item 6) is a documentation task, not a code task. Worth keeping the issue alive as a long-shot.

## Success Criteria

The epic is done when:

- [ ] One placeholder issue exists for each SPEC §12 item.
- [ ] Each placeholder has the `needs-spec` label and a reference back to its SPEC paragraph.

## Child Issues

_Filled in after child issues are filed (Step 8/9 of spec-decomposition)._

- [ ] #67 — Future: Pill imagery via NLM RxImage API (SPEC §12.1) (EPIC_11_ISSUE_01).
- [ ] #68 — Future: iCloud sync for multi-device via CloudKit-backed SwiftData (SPEC §12.2) (EPIC_11_ISSUE_02).
- [ ] #69 — Future: Caregiver mode (SPEC §12.3) (EPIC_11_ISSUE_03).
- [ ] #70 — Future: Health dose readback enrichment via `HKAnchoredObjectQuery` (SPEC §12.4) (EPIC_11_ISSUE_04).
- [ ] #71 — Future: Apple Watch Ultra Action Button binding (SPEC §12.5) (EPIC_11_ISSUE_05).
- [ ] #72 — Future: File Apple Feedback Assistant request for `HKMedicationDoseEvent` write capability (SPEC §12.6) (EPIC_11_ISSUE_06).

## Sequencing Notes

- **Depends on:** Nothing for filing. Individual items depend on v1 being done.
- **Unblocks:** Nothing.
- **Parallel-safe:** Yes, but they are deliberately blocked behind v1 unless a specific item is later prioritized.

## SPEC Reference

`plans/SPEC.md` §12 (Open Questions / Future Work, lines 536-563).

## Labels

`epic`, `spec-decomposition`, `future-work`, `needs-spec`.
