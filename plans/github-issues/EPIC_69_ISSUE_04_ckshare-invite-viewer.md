## Role

You are a senior CloudKit / SwiftUI engineer wiring the actual share: the patient invites a caregiver by Apple ID via `UICloudSharingController` with a `.readOnly` participant, and the caregiver gets a read-only viewer of the consented projection.

## Goal

The patient creates a `CKShare` over the custom shared zone and invites a caregiver via `UICloudSharingController`; the participant permission is `.readOnly`. The caregiver accepts on their device and sees a read-only, clearly-labeled view of the consented projection ("Viewing Geoff's regimen — read only"), with no logging or edit affordances anywhere.

## Context

- **Parent epic:** #69
- **Predecessors:** ISSUE_02 (shared zone + projection write) and ISSUE_03 (consent gating). Only consented records exist to share.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §5.1 (CKShare), §5.3 (trust direction / write protection), §7 (Caregivers section + caregiver-side view), §11 (UICloudSharingController maturity / form factor open).
- **Files involved:**
  - The shared zone + `CaregiverProjectionStore` from ISSUE_02; the consent model from ISSUE_03.
  - iPhone Settings → Caregivers: an **Invite caregiver** action presenting `UICloudSharingController`.
  - The caregiver read-only viewer surface (form factor — same binary viewer mode vs. lightweight target — **decide at grooming**; build the read-only render either way).
- **Prior decisions (locked):**
  - Identity/auth via Apple ID + `UICloudSharingController`; we write zero auth code.
  - Participant permission is `.readOnly` — the caregiver cannot write to the shared zone.
  - The caregiver-side view is read-only, monochrome Liquid Glass, clearly labeled, with **no logging controls, no edit controls**.
  - The watch is never a participant and never sees the share; `LogSource` is not extended.
  - If `UICloudSharingController` can't express the desired read-only/field-minimized permission, fall back to a custom invite over the share metadata (note it in the PR).

## Output Format

A single PR containing:

- [ ] `CKShare` create over the custom zone; **Invite caregiver** via `UICloudSharingController`; participant added `.readOnly`.
- [ ] Caregiver read-only viewer rendering the consented projection; labeled "Viewing <name>'s regimen — read only"; no edit/log affordances.
- [ ] Settings → Caregivers list shows current shares ("Freedom — can see regimen + adherence").
- [ ] Tests (CloudKit-gated for headless CI; share/permission logic asserted where possible):
  - the created participant permission is `.readOnly` (write attempts rejected).
  - the viewer renders only the consented surfaces; no edit/logging affordance exists in the view hierarchy.
  - the watch is never added as a participant (no code path does so).

## Examples

```swift
let share = CKShare(rootRecord: projectionRoot)
share[CKShare.SystemFieldKey.title] = "PillBreakfast — caregiver view" as CKRecordValue
// participant added with permission == .readOnly via UICloudSharingController
```

## Constraints

**Scope fence:** Share create/invite + read-only viewer only. **No** revocation/account-switch/staleness (ISSUE_05), **no** privacy/compliance polish (ISSUE_06). No write path for the caregiver, ever. No watch participation.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; with no invite created nothing is shared. A patient can invite a caregiver who then sees a read-only view of exactly the consented surfaces. The watch and the logging ritual are unaffected.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `core`, `concurrency`
