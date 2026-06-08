## Role

You are a senior iOS engineer shipping the release-gating polish for CloudKit sync: the privacy nutrition-label delta, the in-app disclosure, and the CloudKit dev→prod schema-promotion step in the release runbook.

## Goal

Declare that PillBreakfast stores health data in the user's private iCloud (nutrition label + in-app disclosure), document that disabling iCloud and reinstalling won't silently re-upload unless re-enabled, and add the CloudKit dev→prod schema-promotion step to the release process so the feature can ship to the App Store.

## Context

- **Parent epic:** #68
- **Predecessors:** ISSUE_01–04 (CloudKit fully functional and reconciled behind the opt-in).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-68_icloud-cloudkit-sync.md` §9 (privacy/security/compliance), §11 (dev/prod schema promotion), §13 (acceptance).
- **Files involved:**
  - iOS privacy nutrition-label configuration / `PrivacyInfo.xcprivacy` (and App Store Connect copy as a documented step).
  - The in-app disclosure surface introduced in ISSUE_03 (extend the explainer copy).
  - The release runbook / docs (e.g. under `plans/` or repo docs) — add the CloudKit schema-promotion step.
- **Prior decisions (locked):**
  - This is **PHI in the cloud** — CloudKit private database, end-to-end scoped to the user's Apple ID, encrypted in transit and at rest by Apple, **not** shared (sharing is #69).
  - Opt-in, not default-on; the user can turn it off and keep using the app locally.
  - Declare "Health & Fitness → Health" / "Sensitive Info" data linked to the user and stored in iCloud; disclose CloudKit usage; no third-party sharing, no tracking, no analytics on synced data.
  - Document that disabling iCloud + reinstalling won't silently re-upload unless re-enabled.
  - CloudKit schema must be promoted dev→prod **before** App Store release.

## Output Format

A single PR containing:

- [ ] Privacy nutrition-label delta (`PrivacyInfo.xcprivacy` + documented App Store Connect copy): health/sensitive data linked to user, stored in iCloud; no third-party sharing/tracking.
- [ ] In-app disclosure extended (private/encrypted iCloud; opt-in; disable+reinstall behavior).
- [ ] CloudKit dev→prod schema-promotion step added to the release runbook.
- [ ] Tests / checks:
  - the `PrivacyInfo.xcprivacy` parses and declares the expected data types (or an equivalent validation check).
  - disclosure copy is present on the first-enable path.

## Examples

```
Release runbook — CloudKit step:
  Before submitting to App Store:
    1. CloudKit Dashboard → promote schema from Development to Production.
    2. Verify the production schema matches the shipped VersionedSchema.
    3. Confirm the private-DB container id matches the entitlement.
```

## Constraints

**Scope fence:** Privacy disclosure + nutrition label + release-runbook step only. **No** new sync behavior, **no** entitlement changes, **no** sharing (that is #69), **no** watch UI.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** The app builds and runs unchanged with sync off; the privacy label + disclosure are present, and the release runbook documents the schema-promotion gate. No functional sync behavior changes.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #68`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `polish`
