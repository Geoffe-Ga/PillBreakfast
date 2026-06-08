## Role

You are a senior CloudKit / Swift 6 engineer hardening the adversarial edges of caregiver mode: immediate revocation, account-switch safety, staleness honesty, and multi-caregiver independence.

## Goal

The patient can revoke a caregiver at any time — tearing down the `CKShare` and deleting the projection records from the shared zone so access ends immediately. Account switches re-scope or invalidate the share (never silently re-point to a different Apple ID). The caregiver view shows a "last updated" timestamp and never a false "all taken." Multiple caregivers are independent shares with independent consent and revocation.

## Context

- **Parent epic:** #69
- **Predecessors:** ISSUE_04 (share + viewer exist).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §5.4 (revocation tears down share + deletes records), §8 (edge cases / failure modes), §9 (immediate + total revocation, can't-un-see disclosure).
- **Files involved:**
  - The share/zone/projection code from ISSUE_02 and ISSUE_04; the consent + audit model from ISSUE_03.
  - The caregiver viewer from ISSUE_04 — add the "last updated" staleness banner and decline/pending states.
- **Prior decisions (locked):**
  - Revocation removes the participant / deletes the `CKShare` **and** deletes the projection records from the shared zone; access ends immediately. Patient-controlled, first-class.
  - **No residual-cache guarantee** — honestly message that already-seen data can't be un-seen (a caregiver could have screenshotted). The copy itself ships in ISSUE_06; the behavior (delete records, end access) ships here.
  - Account switch (either side): re-scope or invalidate; **never** silently re-point a share to a different Apple ID.
  - Stale projection (patient offline): caregiver sees last-synced projection with a "last updated" timestamp — never a false "all taken."
  - Multiple caregivers: each is a separate participant with independent consent + revocation.
  - Patient disables #68 CloudKit / deletes app → all shares collapse; document the dependency.

## Output Format

A single PR containing:

- [ ] Revoke action: tear down the `CKShare` + delete the shared-zone projection records; audit-log the revocation.
- [ ] Account-switch handling: re-scope/invalidate the share; never silent re-point; surface a "signed-in account changed" note.
- [ ] Caregiver viewer "last updated" staleness banner; decline/pending states ("invited, not yet accepted").
- [ ] Multi-caregiver independence (revoking one leaves others intact).
- [ ] Tests (CloudKit-gated for headless CI; teardown/state logic asserted where possible):
  - revoke deletes the projection records and removes the participant.
  - account switch never merges/re-points to a different Apple ID.
  - stale projection renders "last updated <time>," never a false "all taken."
  - revoking caregiver A leaves caregiver B's share intact.

## Examples

```swift
func revoke(_ caregiver: CaregiverID) async throws {
  try await deleteProjectionRecords(for: caregiver)   // shared-zone records gone
  try await deleteShare(for: caregiver)               // participant access ends now
  audit.log(.revoked(caregiver, at: .now))
}
```

## Constraints

**Scope fence:** Revocation + account-switch + staleness + multi-caregiver only. **No** new sharing surfaces, **no** consent-model changes (ISSUE_03), **no** privacy copy/compliance (ISSUE_06 owns the "can't un-see" wording + nutrition label).

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; a patient can revoke a caregiver and that caregiver's access + records are gone immediately, while other caregivers are unaffected. Account switches never merge users. The watch and logging ritual are untouched.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `edges`, `concurrency`
