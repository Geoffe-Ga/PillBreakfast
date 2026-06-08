## Role

You are a senior iOS engineer shipping the release-gating polish for the most PHI-sensitive feature in the backlog: the plain-language consent screen, the privacy nutrition-label delta, the honest "can't un-see" disclosure, and the legal/compliance sign-off gate.

## Goal

Ship a plain-language consent screen shown at invite time (exactly what the caregiver will see, that they can be removed anytime, that this is medical data, and that already-seen data can't be un-seen), the privacy nutrition-label delta declaring health-data sharing with other users when enabled, and a documented legal/compliance review sign-off that **gates shipping**.

## Context

- **Parent epic:** #69
- **Predecessors:** ISSUE_01–05 (caregiver mode fully functional behind consent + revocation).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §9 (privacy/security/compliance — highest-stakes), §7 (consent screen at invite), §11 (compliance posture; can't-un-see wording), §13 (acceptance — compliance signed off).
- **Files involved:**
  - The invite flow from ISSUE_04 — attach the consent screen ahead of the `UICloudSharingController` presentation.
  - iOS privacy nutrition-label config / `PrivacyInfo.xcprivacy` (+ App Store Connect copy as a documented step).
  - The release runbook / docs — add the legal/compliance sign-off gate as a prerequisite before this feature ships.
- **Prior decisions (locked):**
  - The defining risk is **PHI leaving the patient's sole control**. Mitigations already built: read-only, minimal projection (no notes), per-surface consent, first-class revocation, Apple-managed encryption/identity, no operated server, no analytics.
  - Threat model includes an **adversarial ex-caregiver**: revocation is immediate/total within CloudKit's control; honestly disclose that already-seen data can't be un-seen.
  - Privacy nutrition label must disclose sharing of health data with other users **when the feature is enabled**.
  - Legal/compliance review is a **gating prerequisite before this ships** — flagged, not hand-waved. Get the "can't un-see" wording right with privacy review.

## Output Format

A single PR containing:

- [ ] Plain-language consent screen at invite time: exactly what the caregiver will see; removable anytime; this is medical data; already-seen data can't be un-seen.
- [ ] Privacy nutrition-label delta (`PrivacyInfo.xcprivacy` + documented App Store Connect copy): health data shared with other users when caregiver mode is enabled; no third-party processors; no tracking; CloudKit only.
- [ ] Legal/compliance sign-off gate added to the release runbook as a ship prerequisite.
- [ ] Tests / checks:
  - the consent screen is presented before the share is created (not after).
  - `PrivacyInfo.xcprivacy` parses and declares the health-data-sharing types (or an equivalent validation).
  - the "can't un-see" disclosure copy is present on the consent screen.

## Examples

```
Release runbook — caregiver-mode gate:
  Before shipping caregiver mode:
    [ ] Legal/compliance review signed off (consumer PHI sharing).
    [ ] Privacy nutrition label declares health-data sharing with other users.
    [ ] Consent screen copy reviewed by privacy ("can't un-see" wording approved).
```

## Constraints

**Scope fence:** Consent screen copy/presentation + privacy label + compliance gate only. **No** new sharing behavior, **no** changes to revocation/zone/share logic (owned by earlier children). The watch is untouched.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; the consent screen gates every invite, the privacy label declares the sharing, and the runbook documents the compliance sign-off gate. No functional sharing behavior changes from ISSUE_05.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `polish`
