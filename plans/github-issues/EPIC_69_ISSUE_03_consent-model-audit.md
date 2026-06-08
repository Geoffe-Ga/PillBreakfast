## Role

You are a senior SwiftUI / Swift 6 engineer building the heart of caregiver mode: the per-surface, per-caregiver consent model that actually gates which projection records get written, plus the patient-side audit log of sharing actions.

## Goal

Add granular, explicit, revocable consent: per-caregiver toggles for Regimen, Adherence, and PRN totals (notes/free-text never shareable; timestamp granularity configurable to day-level). The consent state gates which projection records ISSUE_02 writes — a regimen-only share must produce **no** adherence/PRN records. A patient-side audit log records "you started sharing adherence with <name> on <date>."

## Context

- **Parent epic:** #69
- **Predecessors:** ISSUE_02 (shared zone + projection write). This issue gates those writes.
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-69_caregiver-mode.md` §5.4 (consent model — the heart), §7 (UX / Caregivers section), §9 (consent logged), §10 (consent toggles gate writes).
- **Files involved:**
  - The consent model store (new, e.g. `Shared/Caregiver/CaregiverConsent.swift`) — per-caregiver, per-surface flags + an audit log.
  - The `CaregiverProjectionStore` from ISSUE_02 — read consent before writing each projection record kind.
  - The iPhone Settings → Caregivers section (SPEC §6.3) — per-caregiver consent toggles + a clear "what this person can see" summary.
- **Prior decisions (locked):**
  - Surfaces and defaults: Regimen (opt-in), Adherence (opt-in, separate toggle), PRN totals (opt-in, separate, **off by default** — most sensitive), Notes/free text (**never shared**, excluded at the projection-schema level), exact timestamps (configurable; option for day-level status only).
  - Consent is **per-caregiver** and **revocable at any time**, with a clear in-app summary.
  - Consent is **logged** (patient-side audit) so the patient can review their own sharing history.
  - Toggles must be enforceable, not cosmetic — a disabled surface produces no record of that kind.

## Output Format

A single PR containing:

- [ ] Per-caregiver, per-surface consent model (Regimen / Adherence / PRN; timestamp granularity) with the locked defaults.
- [ ] `CaregiverProjectionStore` reads consent and writes **only** the consented record kinds.
- [ ] Patient-side audit log of sharing/consent changes with timestamps.
- [ ] Settings → Caregivers per-caregiver toggles + "what this person can see" summary (monochrome Liquid Glass; no accent color).
- [ ] Tests:
  - a regimen-only consent produces a regimen projection and **no** adherence/PRN records.
  - enabling PRN later adds PRN records; disabling removes them on next refresh.
  - notes/free-text never appear regardless of consent (already impossible at the type level — assert it).
  - each consent change appends an audit entry.

## Examples

```swift
struct CaregiverConsent: Sendable, Codable {
  var shareRegimen = false
  var shareAdherence = false
  var sharePRNTotals = false   // most sensitive; off by default
  var timestampGranularity: Granularity = .dayLevel
  // notes are not representable — never shared
}
```

## Constraints

**Scope fence:** Consent model + gating + audit log + the Settings toggles only. **No** `CKShare`/invite (ISSUE_04), **no** caregiver viewer, **no** revocation tear-down (ISSUE_05). Notes stay non-representable.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run unchanged; with all consent off (default) nothing is written to the shared zone. Toggling a surface on gates exactly which projection records ISSUE_02 writes. The watch is untouched.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #69`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `v2`, `core`
