## Role

You are a senior watchOS engineer landing the consumption end of Health dose readback: the watch suppresses pending-dose cards and notifications for slots the user already took in Health, and un-suppresses when a Health dose is retracted or was never `.taken`. This is the edges child — it closes the loop and handles the failure modes (retraction, skip, stale day, declined auth).

## Goal

Plug the synced `healthSuppressedSlots` (from `RegimenSnapshot` v5) into the two centralized watch plug points: `PendingQueueSelector.pendingDoses(at:in:)` excludes any suppressed slot for `now`'s day, and `NotificationBootstrap.refresh(from:)` omits suppressed slots' `UNCalendarNotificationTrigger`s during its full rebuild. Handle retraction/skip (the slot re-surfaces), day-scoping (stale next-day suppressions are filtered on apply), and declined auth (empty set → identical to v1, fail open to prompting).

## Context

- **Parent epic:** #70
- **Predecessor:** #70 child #04 (`EPIC_70_ISSUE_04_regimen-snapshot-v5-wc-push.md` — the resolved, day-scoped suppression set now arrives inside the regimen snapshot).
- **Spec sections:** `plans/2026-06-07_SPEC_ISSUE-70_health-dose-readback.md` §5.6 (watch-side consumption — the two plug points; suppress vs. annotate), §8 (edge cases: retraction un-suppresses, skipped leaves prompt intact, watch offline / stale-day filter, midnight clock skew, dedup), §10 (`PendingQueueSelector` + `NotificationBootstrap` suppression tests).
- **Files involved:**
  - `Shared/Queue/PendingQueueSelector.swift` — after computing `loggedSlots`, also exclude slots in `healthSuppressedSlots` for `now`'s day (union the sets, keyed on `SlotKey(medicationID, hour, minute)`), using the injected `Calendar`.
  - `Shared/Notifications/NotificationBootstrap.swift` (and `NotificationScheduler.swift` as needed) — skip suppressed slots when rebuilding `UNCalendarNotificationTrigger`s (full rebuild, not a diff).
  - the watch-side `RegimenSnapshot.apply(...)` path — seat the suppression set into the store/state the selector + bootstrap read, dropping stale (non-today) suppressions on apply.
- **Prior decisions (locked):**
  - Two plug points only, both already centralized: `PendingQueueSelector` (a one-line addition to the existing `guard !loggedSlots.contains(slotKey)` filter — union or check both sets) and `NotificationBootstrap.refresh` (suppression is just another input to the existing "full rebuild on regimen change, not a diff" rule).
  - Default behavior is **suppress** (cleanest; matches §12.4 "avoid double-prompting"). The **annotate** fallback ("Logged in Health ✓" subdued card) and its Settings toggle are **deferred** to a dogfooding-gated follow-up — do not build annotate mode here.
  - A **retracted** Health dose (delivered via the readback's deletion path, re-pushed by #04) must **un-suppress** — the slot re-surfaces and its notification returns. A `.skipped`/`.missed` Health dose never suppressed in the first place (the query filters to `.taken`).
  - Suppression is **day-scoped**: only today's slot is suppressed; a stale (yesterday) suppression is filtered out on apply. Day boundaries use each device's local calendar (the selector's injected `Calendar`) — edge slots near midnight may briefly disagree; acceptable since the failure is at worst an extra prompt.
  - **Fail open:** declined auth → empty suppression set → behavior identical to v1 (prompt as normal). Never fail into silence on a safety-critical med.
  - Suppressing a high-risk med (lithium) is safe by construction: removing a prompt can only cause a *missed* PillBreakfast prompt for a dose Health already confirmed, never a double-dose.
  - **No `DoseEvent` is ever fabricated** from a suppression; PRN totals and the PDF export are unaffected.

## Output Format

A single PR containing:

- [ ] `PendingQueueSelector.pendingDoses(at:in:)` excludes slots present in the synced `healthSuppressedSlots` for `now`'s day, alongside the existing `loggedSlots` filter, keyed on `SlotKey` with the injected `Calendar`.
- [ ] `NotificationBootstrap.refresh(from:)` omits the `UNCalendarNotificationTrigger` for any suppressed slot that day during the full rebuild.
- [ ] `RegimenSnapshot.apply(...)` (watch side) seats the suppression set and drops stale (non-today) suppressions on apply.
- [ ] Tests (reusing the deterministic `now` + injected `Calendar` contract):
  - a suppressed slot is excluded from the pending set;
  - a suppression for a **different** day is ignored;
  - a retraction (suppression removed from the set) re-surfaces the slot;
  - a suppressed slot produces **no** `UNCalendarNotificationTrigger`;
  - an empty suppression set (declined auth) leaves behavior identical to today.
- [ ] End-to-end manual verification on a real device documented in the PR: log a dose in Apple Health, confirm the watch prompt disappears within one foreground/background cycle; retract it, confirm the prompt returns.

## Examples

```swift
// Shared/Queue/PendingQueueSelector.swift — alongside the existing logged-slot filter:
let suppressed = Set(
    snapshot.healthSuppressedSlots
        .filter { calendar.isDate($0.day, inSameDayAs: now) }
        .map { SlotKey(medicationID: $0.medicationID, hour: $0.hour, minute: $0.minute) }
)
// ...
guard !loggedSlots.contains(slotKey), !suppressed.contains(slotKey) else { continue }
```

## Constraints

**Scope fence:** Watch-side consumption at the two centralized plug points + retraction/skip/day-scope/fail-open handling only. **No** annotate mode and **no** Settings toggle (deferred, dogfooding-gated). **No** HealthKit code on the watch (the Medications API is iOS-only — the watch only sees resolved `(medicationID, hour, minute, day)`). **No** new query/matcher/sync work (children #02–#04). **No** fabricated `DoseEvent`.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Both apps build and run on the paired simulator. With the full chain (auth → query → matcher → sync → consumption) landed, a dose logged in Apple Health suppresses the matching watch card and notification for that day; a retracted/skipped Health dose un-suppresses; declined auth behaves exactly like v1. No history or PRN total is ever altered by suppression.

## Done-Done
- [ ] iOS scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast' -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`
- [ ] watch scheme builds & all tests pass: `xcodebuild test -project PillBreakfast.xcodeproj -scheme 'PillBreakfast Watch App Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'`
- [ ] `pre-commit run --all-files` is clean.
- [ ] PR opened with `Closes #<this issue>` and `Refs #70`.
- [ ] Latest Claude reviewer `Verdict:` on HEAD is `LGTM`.

## Labels

`spec-decomposition`, `future-work`, `edges`, `notifications`, `concurrency`
