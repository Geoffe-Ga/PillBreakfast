## Role

You are a senior watchOS engineer wiring the SnoozeView UI to the reschedule logic.

## Goal

Replace the stub `SnoozeView` with a real Liquid Glass screen containing a `DatePicker(displayedComponents: .hourAndMinute)` and a Done button. Done calls `SnoozeRescheduler.snooze(...)` with the picked time, then dismisses. Picker defaults to "now + default offset" from `UserPreferences` (introduced in EPIC_06_ISSUE_05; in this issue, default to 30 minutes from now).

## Context

- **Parent epic:** #6
- **Predecessor issue(s):** #EPIC_06_ISSUE_02_NUMBER.
- **SPEC section:** `plans/SPEC.md` §2.2, §8.3 steps 2-3.
- **Files updated:** `WatchApp Watch App/SnoozeView/SnoozeView.swift`.
- **Prior decisions (locked):**
  - Liquid Glass styling per EPIC 04 design system.
  - The user is shown the resolved target time at the bottom of the picker ("Will fire 10:17 PM today"), updated live. If the target rolls into tomorrow (post-midnight), the label says so explicitly.
- **State of the world:** Reschedule logic exists; UI is a stub.

## Output Format

A single PR containing:

- [ ] `SnoozeView` with the picker, Done button, and live target-time label.
- [ ] Picker default = `now + 30min` (default offset constant lives here for now; EPIC_06_ISSUE_05 promotes it to a user preference).
- [ ] Done calls `SnoozeRescheduler.snooze(...)` and dismisses.
- [ ] Cancel button.
- [ ] Snapshot tests for the view (idle / mid-picker).
- [ ] Manual checklist: tap Snooze on an active notification, pick 10:17 PM, confirm a new notification fires at 10:17 PM.

## Examples

```swift
struct SnoozeView: View {
    let scheduledDoseID: UUID
    let originalScheduledFor: Date

    @State private var snoozeTime: Date = .now.addingTimeInterval(30 * 60)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.standard) {
            DatePicker("Snooze until", selection: $snoozeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Text(targetLabel)
                .font(LiquidGlassTheme.Typography.dosage)
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)

            HStack {
                Button("Cancel") { dismiss() }
                Button("Done") {
                    Task { await confirm() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .glassBackground()
    }
}
```

## Constraints

**Scope fence:** No `snoozeCount` counter — EPIC_06_ISSUE_04. No iPhone settings entry — EPIC_06_ISSUE_05.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** End-to-end snooze flow works (without the fourth-snooze warning, which is next).

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair; manual snooze-to-10:17PM checklist completes.
- [ ] PR opened with `Refs #6` and `Closes #EPIC_06_ISSUE_03_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-5-snooze`.
