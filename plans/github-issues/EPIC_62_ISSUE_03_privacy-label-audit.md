## Role

You are a privacy/compliance reviewer auditing PillBreakfast's App Store privacy nutrition label and HealthKit usage descriptions against the actually-shipped codebase, so the submission cannot claim anything the app does not do.

## Goal

Perform a line-by-line audit of `Submission/privacy-nutrition.md` and `PillBreakfast/Info.plist` against current code: confirm `NSHealthUpdateUsageDescription` is absent (read-only import constraint), `NSHealthShareUsageDescription` is present with read-only language, the Diagnostics row is MetricKit-only ("Not Collected"), and Tracking is "No". Produce the PR "Anonymization audit" section content the rest of #62 references. Correct the privacy label only if the audit finds it inaccurate.

## Context

- **Parent epic:** #62.
- **Predecessors:** can run in **parallel** with the two capture children (it needs the §5.2 seed only for the anonymization-audit checklist, not for capture). It blocks the submission checklist but not screenshot capture.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-62_screenshots-marketing-copy.md` §4 (existing submission artifacts state), §5.5 (privacy nutrition label review — the four audit steps + the required PR "Anonymization audit" section), §8 (acceptance — privacy-label block), §9 (privacy-policy-URL open question).
- **Files involved:**
  - `Submission/privacy-nutrition.md` (existing — audited; replaced only if corrections are needed).
  - `PillBreakfast/Info.plist` (read — verify HealthKit usage-description keys).
  - `plans/decisions/2026-05-29_crash-reporting.md` (read — confirms MetricKit-only, so Diagnostics → Crash Data stays "Not Collected").
- **Prior decisions (locked):**
  - **HealthKit is read-only import only** (SPEC §3.2, CLAUDE.md). `NSHealthUpdateUsageDescription` **must remain absent** — if it is present, that is a bug in the iOS target's capabilities setup, not something to paper over in the label.
  - `NSHealthShareUsageDescription` must be present with language reflecting read-only import — suggested: "PillBreakfast can import your medications from Apple Health to speed up setup. It reads medication names and schedules; it does not write to Apple Health."
  - The crash-reporting ADR is **MetricKit-only**; if `sentry-cocoa` (or any third-party SDK) has been linked since that ADR, the Diagnostics/Identifiers rows need revision **before** submission — flag it, do not silently pass.
  - App Store Connect "Tracking" = **No** (no IDFA, no ATT prompt, no cross-app tracking).

## Output Format

A single PR (or a PR comment if no file changes are needed) containing:

- [ ] An audit result confirming each of the four §5.5 checks (Update key absent / Share key present + correct text / Diagnostics MetricKit-only / Tracking No), with the exact `NSHealthShareUsageDescription` string as it appears in `Info.plist` quoted.
- [ ] Corrections to `Submission/privacy-nutrition.md` only if the audit found an inaccuracy (otherwise the file is unchanged and the PR states "no corrections needed").
- [ ] The reusable **"Anonymization audit"** section content (med-name stand-in confirmation, the Share-key string, and the no-new-SDK-since-MetricKit-ADR confirmation) that the screenshot children paste into their PR bodies.
- [ ] If a third-party SDK has been added since the ADR, a filed follow-up issue to revise the nutrition label, linked from this PR.

## Examples

The four audit checks (SPEC §5.5) and their pass conditions:

```
1. NSHealthUpdateUsageDescription   -> ABSENT in PillBreakfast/Info.plist (read-only constraint)
2. NSHealthShareUsageDescription    -> PRESENT, read-only language (quote the exact string)
3. Diagnostics -> Crash Data        -> "Not Collected" (MetricKit-only per the 2026-05-29 ADR)
4. App Store Connect "Tracking"     -> "No" (no IDFA / ATT / cross-app tracking)
```

Suggested Share-key text to verify against (or flag a delta):

```
PillBreakfast can import your medications from Apple Health to speed up setup.
It reads medication names and schedules; it does not write to Apple Health.
```

## Constraints

**Scope fence:** Privacy-label + Info.plist audit only. **Do not** capture screenshots, **do not** write the marketing copy deck (sibling children). **Do not** add or remove any capability or SDK — if the audit surfaces a capabilities bug (e.g., the Update key is present, or a new SDK is linked), **file an issue**; fixing it is out of scope for this audit.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** This is a read-mostly audit — the app builds and runs unchanged. The only permissible file change is a documented correction to `Submission/privacy-nutrition.md` if the codebase no longer matches it.

## Done-Done

- [ ] Existing tests pass (audit is read-only / Markdown-only; no Swift change unless a correction is documented).
- [ ] `NSHealthUpdateUsageDescription` confirmed **absent** and `NSHealthShareUsageDescription` confirmed **present** with read-only language (string quoted in the PR).
- [ ] `Submission/privacy-nutrition.md` Diagnostics row confirmed accurate (MetricKit-only = "Not Collected"); Tracking confirmed "No"; no third-party SDK added since the MetricKit ADR (or a follow-up issue filed).
- [ ] The reusable "Anonymization audit" section content is in the PR for the capture children to reuse.
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #62`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `polish`, `phase-9-hardening`, `docs`
