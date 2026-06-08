# SPEC — Issue #71: Apple Watch Ultra Action Button Binding ("Log Next Pill")

| Field | Value |
|---|---|
| Issue | #71 |
| Phase | Future Work (SPEC §12.5) |
| Labels | `spec-decomposition`, `future-work`, `needs-spec` |
| Status | Draft |
| Date | 2026-06-07 |
| Epic | #11 |
| Related | #51 / EPIC 08 ISSUE 04 (`LogNextDoseIntent` — the widget intent this reuses), EPIC 04 (press-and-hold high-risk safety) |

---

## 1. Summary

The Apple Watch Ultra has a physical **Action Button**. This feature binds it to "log the next
pending pill" so Geoff can confirm a dose without raising his wrist into the app — one press,
done. The implementation is a thin layer over machinery that already exists: the widget's
`LogNextDoseIntent` (EPIC 08 ISSUE 04) already encodes the exact contract we need, **including the
non-negotiable safety rule that high-risk meds are never one-press logged**. For high-risk doses
the Action Button must *open the press-and-hold confirm screen* instead of logging directly,
exactly as the Smart Stack widget does. The work is: expose a runnable `AppIntent`, make it the
Action Button's bound intent, branch on `isHighRisk`, and handle the reality that the Action
Button is Ultra-only.

---

## 2. Problem Statement / Motivation

**Value.** The product thesis is "zero-ambiguity tap-through logging on the device already on the
wrist." The Action Button is the lowest-friction logging surface possible on an Ultra: a tactile,
eyes-free, single-press confirm. For a maintenance regimen (most of Geoff's daily pills are
single-tap-safe vitamins/maintenance meds), this turns the morning ritual into a literal button
press. It complements — does not replace — the tap-through queue and the Smart Stack widget.

**Why deferred.** It is Ultra-only hardware, a genuine nice-to-have layered on top of the full
logging stack. It cannot be built before the dose-logging path, the high-risk press-and-hold
gesture (EPIC 04), and the widget intent (EPIC 08) all exist — and they now do. It is parked in
future-work because the core wrist UX must prove out first, and because Action Button binding
specifics on watchOS 26 warrant confirmation against the shipping SDK before committing.

---

## 3. Goals and Non-Goals

**Goals**
- Bind the Ultra Action Button to an `AppIntent` that logs the **next pending maintenance dose**.
- Reuse the existing dose-logging path (`DoseEventWriter.writeDoseEvent`) and pending-dose
  selection (`PendingQueueSelector`) — no parallel logging logic.
- For a high-risk next dose, **do not log**; instead open the app onto the press-and-hold confirm
  screen for that dose. Identical guarantee to the widget (EPIC 08 ISSUE 04).
- Handle Ultra-only availability gracefully on non-Ultra hardware (no broken UI, no crash, a clear
  "this requires Apple Watch Ultra" state where the binding would be configured).
- Provide haptic + complication-refresh feedback after a successful one-press log (the press is
  eyes-free, so feedback must be felt, not just seen).

**Non-Goals**
- Logging PRN doses via the Action Button. PRN requires a quantity choice and a `violationsIfTaken`
  safety check (SPEC §5.3, `SafetyEvaluator`) — there is no unambiguous "next" PRN dose to one-press.
  PRN stays in the tap-through PRN section. (Possible future extension; out of scope.)
- Any Action Button surface on iPhone. The iPhone never logs (SPEC §6, CLAUDE.md).
- Changing the high-risk safety model. The press-and-hold gesture and its progress ring (EPIC 04)
  are inherited verbatim.
- One-press logging of a *meal* (multiple doses at once). The button logs exactly one "next" dose;
  meal grouping stays in the tap-through queue.

---

## 4. Background and Current State

### 4.1 SPEC text (quoted)

SPEC §12.5:

> "Apple Watch Ultra Action Button binding. 'Log next pill' on a press. Deferred."

Issue #71 context (verbatim from the placeholder):

> "High-risk meds: same rule as EPIC 08's widget — open to confirm, don't log directly.
> Implementation likely a single `AppIntent` plus an action-button configuration update."

And the hard constraint:

> "**One-tap log on high-risk is forbidden.** Inherit from EPIC 04 and EPIC 08."

### 4.2 What already exists

- **The widget intent contract (EPIC 08 ISSUE 04, `Shared/Intents/LogNextDoseIntent.swift`).** Its
  spec already states the exact rules we need: "logs the next pending dose when invoked," "the
  widget surface for high-risk meds opens the app to the press-and-hold screen instead of logging
  directly," "the intent calls `DoseEventWriter.writeDoseEvent(...)` via the App Group's SwiftData
  container," and "after a successful log, `WidgetCenter.shared.reloadAllTimelines()`." The Action
  Button reuses this intent — or a thin sibling that delegates to the same core — so the two
  surfaces are guaranteed to behave identically. **This is the single most important reuse: there
  must not be two copies of the "is this dose safe to one-press?" decision.**
- **`PendingQueueSelector.pendingDoses(at:in:)`** (`Shared/Queue/PendingQueueSelector.swift`) —
  returns the ordered pending set; element 0 is "the next pill." `PendingDose` already carries
  `medicationID`, `scheduledFor`, `quantity`. The intent resolves the `Medication` to read
  `isHighRisk`.
- **`DoseEventWriter.writeDoseEvent(for:scheduledFor:quantity:status:loggedOn:at:in:)`**
  (`Shared/Logging/DoseEventWriter.swift`) — the sole, `@MainActor` dose-write path. Builds the
  denormalized `ingredientAmounts` snapshot at log time. The intent calls this with
  `loggedOn: .watch`.
- **`Medication.isHighRisk`** (`Shared/Models/Medication.swift`) — computed: true if any component's
  ingredient `isHighRisk`. This is the branch condition.
- **`DoseEventBatchTransfer.transfer(_:)`** (`Shared/Sync/DoseEventBatchTransfer.swift`) — queues
  the logged event to the iPhone. The intent calls this after a successful write (non-fatal on
  failure, mirroring `TapThroughQueueView.log`).
- **The press-and-hold confirm screen + deep-link router** — `TapThroughQueueView` / `MarkTakenView`
  render the press-and-hold ring for high-risk meds (`UserPreferences.highRiskHoldDurationSeconds`).
  `NotificationActionRouter` (`PillBreakfast Watch App Watch App/Bootstrap/NotificationActionRouter.swift`)
  already demonstrates the pattern for routing an out-of-band action (a notification tap) into the
  SwiftUI hierarchy via an `@Observable` `@MainActor` router. The Action Button's high-risk path
  reuses exactly this routing pattern: stash a target and let the root view present the confirm
  screen.

### 4.3 The reuse symmetry that matters

The widget (tap a complication) and the Action Button (press the physical button) are two entry
points to the *same* decision tree:

```
next pending dose?
 ├─ none            → no-op + "all caught up" feedback
 ├─ high-risk       → open app to press-and-hold confirm screen (NEVER auto-log)
 └─ not high-risk   → DoseEventWriter.write(.taken) + transfer + reload timelines + haptic
```

This SPEC's core engineering instruction is: **factor that decision tree into one place** (the
intent's `perform()` body or a shared helper it and the widget both call) so EPIC 08 and #71 can
never drift apart on the safety rule.

---

## 5. Detailed Design

### 5.1 How watchOS 26 exposes the Action Button

On watchOS, the Action Button is configured by the *user* in Settings → Action Button, which lets
them pick an app and one of the app's offered actions. An app surfaces Action-Button-eligible
actions as **App Intents** (the App Intents framework is the modern integration story for
Siri/Spotlight/widgets/Action Button — SPEC §11 Phase 7 callout). The contract:

- Ship an `AppIntent` that the system can present as an Action Button option (an
  `AppShortcutsProvider` exposing the intent makes it discoverable to the system action surfaces).
- The intent's `perform()` runs when the button is pressed. For the non-high-risk path it returns
  a result silently (`openAppWhenRun = false`); for the high-risk path it must bring the app
  forward (`openAppWhenRun = true`) and route to the confirm screen.

> **Open (confirm against Xcode 26 SDK):** the exact mechanism by which a watchOS 26 app declares an
> intent as Action-Button-bindable (vs. only Siri/Shortcuts) — whether it's purely via
> `AppShortcutsProvider`, a specific intent protocol, or an `Info.plist` declaration. The shape below
> assumes the App Intents route; verify before implementation (§11).

### 5.2 The intent

Reuse `LogNextDoseIntent` if its surface fits, or add a thin `LogNextPillActionButtonIntent` that
delegates to the same shared core. Either way, the core is one function:

```swift
// Shared/Intents/ — same module as LogNextDoseIntent so the safety decision is shared.
struct LogNextPillIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Next Pill"
    // Default false: a non-high-risk log is silent/eyes-free. Flipped to true at
    // runtime for the high-risk path so the confirm screen comes forward (see perform()).
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = PersistenceController.shared.container.mainContext
        let selector = PendingQueueSelector()                 // default ±60min window
        let pending = try selector.pendingDoses(at: .now, in: context)

        guard let next = pending.first else {
            // Nothing due. Eyes-free: a distinct "nothing to do" haptic, no UI.
            await Haptics.play(.allCaughtUp)
            return .result()
        }

        guard let medication = try Self.medication(for: next.medicationID, in: context) else {
            return .result()   // regimen lost it; no-op
        }

        if medication.isHighRisk {
            // FORBIDDEN to auto-log. Route to the press-and-hold confirm screen.
            // Mirrors the widget's deep-link; reuses the NotificationActionRouter pattern.
            ActionButtonRouter.shared.requestHighRiskConfirm(
                ActionButtonConfirmContext(pendingDose: next)
            )
            return .result(opensIntent: OpenConfirmScreenIntent())  // brings app forward
        }

        // Safe path: single-press log, identical to the widget's non-high-risk branch.
        let event = try DoseEventWriter.writeDoseEvent(
            for: medication,
            scheduledFor: next.scheduledFor,
            quantity: next.quantity,
            status: .taken,
            loggedOn: .watch,
            at: .now,
            in: context
        )
        try? feedbackOnly_transfer(event)        // transfer failure is non-fatal (watch is authoritative)
        WidgetCenter.shared.reloadAllTimelines()
        await Haptics.play(.doseLogged)
        return .result()
    }
}
```

Notes:
- The non-high-risk branch is **byte-for-byte the widget's branch** (same writer call, same
  transfer, same `reloadAllTimelines`). Sharing the helper guarantees that.
- `feedbackOnly_transfer` is shorthand for the existing `DoseEventBatchTransfer.transfer([event])`
  wrapped to log-and-continue on failure (matching `TapThroughQueueView.log`). It does **not**
  swallow with a bare `try?` silently — the catch logs via `os.Logger` (anti-bypass compliant).
- The high-risk branch never calls the writer. It routes and opens the app.

### 5.3 The high-risk routing path

Reuse the `NotificationActionRouter` pattern — an `@MainActor @Observable` singleton the root view
observes:

```swift
public struct ActionButtonConfirmContext: Identifiable, Sendable, Hashable {
    public let pendingDose: PendingDose
    public var id: UUID { pendingDose.id }
}

@MainActor
@Observable
public final class ActionButtonRouter {
    public static let shared = ActionButtonRouter()
    /// Non-nil while the root view should present the press-and-hold confirm for this dose.
    public var pendingHighRiskConfirm: ActionButtonConfirmContext?
    public func requestHighRiskConfirm(_ ctx: ActionButtonConfirmContext) {
        pendingHighRiskConfirm = ctx
    }
}
```

`RightNowView` (which already injects and observes `NotificationActionRouter`) gains a sibling
`.onChange`/`.sheet`/navigation on `ActionButtonRouter.pendingHighRiskConfirm` that pushes the
existing high-risk `MarkTakenView` (press-and-hold ring, amber accent, hold duration from
`UserPreferences`). The user then completes the *same* press-and-hold they would in the queue —
the Action Button merely got them to that screen with one press instead of several taps. **The
safety gate is unchanged: lithium still requires the deliberate hold.**

### 5.4 Ultra-only availability

The Action Button hardware exists only on Ultra. Strategy:
- The intent is always shipped and always functional (it's just an App Intent; on non-Ultra it's
  still reachable via Siri/Shortcuts, harmlessly).
- Any *configuration UI or guidance* we surface (e.g., a Settings hint "Bind the Action Button to
  PillBreakfast") is gated behind an Ultra check. There is no public Boolean "isUltra," so detect
  via the supported capability (the system simply won't present the Action Button option on
  non-Ultra). Our guidance copy should therefore be advisory, never asserting the button exists.
- No crash, no dead UI on Series watches — the intent is a no-harm no-op surface there.

### 5.5 Concurrency

- The whole path is `@MainActor` (intent `perform()` annotated `@MainActor`), because
  `DoseEventWriter`, `PendingQueueSelector`, and SwiftData `ModelContext` access are all main-actor
  bound in this codebase. This matches how the widget intent is specified.
- `ActionButtonConfirmContext` / `PendingDose` are `Sendable` value types, safe to cross into the
  router.
- No new actors are required; we reuse `PersistenceController.shared.container.mainContext`, exactly
  as the WC coordinator and widget intent do.

---

## 6. Alternatives Considered

| Option | Verdict |
|---|---|
| Reuse the EPIC 08 `LogNextDoseIntent` core via a shared helper (chosen) | ✅ One safety decision, two entry points; impossible to drift on the high-risk rule. |
| A fully separate Action-Button intent with its own logging logic | ❌ Duplicates the high-risk gate; a future edit to one surface could leave the other unsafe. |
| Action Button auto-logs high-risk meds too (one press) | ❌ Forbidden by EPIC 04/08 and CLAUDE.md. Lithium double-dose risk. Hard no. |
| Action Button logs an entire *meal* (all due doses) in one press | ❌ Multiple meds, possibly including high-risk ones, can't share one confirmation. Stays in tap-through. |
| Action Button supports PRN logging | ❌ PRN needs a quantity pick + `violationsIfTaken` check; no unambiguous "next" dose. Out of scope. |
| Bind via a custom watchOS API rather than App Intents | ⚠️ App Intents is the documented integration path; revisit only if SDK research shows otherwise (§11). |

---

## 7. UX and Visual Design

- **Non-high-risk, one press:** no screen needed. The user feels a confirming haptic
  (`Haptics.play(.doseLogged)`) and the complication count drops by one. Eyes-free by design — the
  whole point of the Action Button.
- **High-risk, one press:** the app comes forward onto the press-and-hold confirm screen for that
  dose. Amber accent + progress ring (the *only* place color appears, per §9/CLAUDE.md). The user
  completes the deliberate hold. If they release early or back out, **nothing is logged** — the
  dose stays pending. The Action Button is an accelerator to the safe screen, never a bypass of it.
- **Nothing due:** a distinct "all caught up" haptic, no app launch. The user learns the difference
  between the "logged" and "nothing to do" taps by feel.
- **Settings (watch, Ultra only):** a one-line hint pointing to system Settings → Action Button,
  shown only where the hardware exists. No logging UI added anywhere on iPhone.

---

## 8. Edge Cases and Failure Modes

- **No pending dose.** No-op + distinct haptic. Never logs a stale/old slot.
- **Next dose is high-risk.** Open confirm; never auto-log. If the app was locked/asleep, the
  routing context persists in the `@MainActor` router until the root view presents it.
- **Regimen lost the medication (synced away).** Resolve fails → no-op (mirrors
  `TapThroughQueueView.doseScreen`'s silent-skip on a missing med).
- **Write fails.** `DoseEventWriter` throws → surface a failure haptic and do **not** mark the dose
  consumed; it stays pending so a re-press retries. (Silent failure on a med tracker is the worst
  outcome — same stance as `TapThroughQueueView`.)
- **Transfer to iPhone fails.** Non-fatal; the watch store is authoritative and reverse-sync retries
  later. Logged via `os.Logger`, not swallowed.
- **Rapid double-press.** The second press recomputes pending; once the first dose is logged it's no
  longer "next," so the second press targets the *next* dose — which is correct, but could surprise.
  Guard with a short in-flight debounce in the router so a double-press doesn't log two different
  pills unintentionally. **Open detail (§11).**
- **Non-Ultra hardware.** Intent still callable via Shortcuts; no Action Button UI surfaces; no
  crash.
- **Pending set changes between selection and write** (e.g., a notification logged it). The
  `loggedDoseIDs`/durable selector dedup means a re-pressed already-logged slot is filtered out;
  worst case is logging the genuinely-next dose.

---

## 9. Privacy, Security and Compliance

- **No new PHI surface.** The Action Button reads the same local SwiftData store and writes the same
  `DoseEvent`s as the tap-through queue. No new data types, no network, no Health access.
- **No HealthKit involvement.** Unlike #70, this feature is entirely PillBreakfast-internal.
- **Color discipline.** Amber remains reserved for the high-risk press-and-hold confirmation only
  (CLAUDE.md §"Color is reserved"). The Action Button's high-risk path inherits that screen as-is.
- **Authorization.** App Intents require no special entitlement beyond the App Group already used
  for the shared store (same as the widget intent).

---

## 10. Testing Strategy

- **Shared decision helper (pure-ish, `@MainActor`):** with an in-memory `ModelContext`:
  - non-high-risk next dose → a `.taken` `DoseEvent` is written with `loggedOn == .watch` and the
    correct `ingredientAmounts` snapshot; `reloadAllTimelines` fires.
  - high-risk next dose → **no** `DoseEvent` is written; the router's `pendingHighRiskConfirm` is set
    to that dose. (This is the load-bearing safety test — mirror EPIC 08 ISSUE 04's "intent returns
    failure gracefully for a high-risk dose" test.)
  - no pending dose → no write, no route, "caught up" feedback path taken.
- **Reuse parity test:** assert the Action Button path and the widget intent path produce identical
  outcomes for the same fixture (ideally by sharing the helper and testing it once, with both
  intents as thin adapters).
- **Router:** `ActionButtonRouter.requestHighRiskConfirm` sets/clears `pendingHighRiskConfirm`;
  debounce suppresses a second in-flight request.
- **Availability:** the intent is a no-op-safe surface on non-Ultra (no crash when invoked).
- **Manual (Ultra hardware or sim that exposes the binding):** bind Action Button → PillBreakfast →
  Log Next Pill; press with a non-high-risk dose due → logged, haptic, no app launch; press with
  lithium due → app opens to press-and-hold, releasing early logs nothing.

---

## 11. Risks and Open Questions

- **Exact watchOS 26 Action Button binding API.** The App Intents route is assumed; confirm against
  the Xcode 26 SDK whether an additional declaration (intent protocol conformance,
  `AppShortcutsProvider`, or Info.plist key) is required for an intent to appear as an Action Button
  option specifically (vs. Siri/Shortcuts only). **Open — verify before coding.**
- **`openAppWhenRun` vs. `opensIntent` for the conditional open.** Whether an intent can decide *at
  runtime* to come forward (high-risk) vs. stay background (safe) cleanly, or whether two intents
  are needed. The sketch uses a returned `opensIntent`; confirm this is supported on watchOS 26.
  **Open.**
- **Double-press debounce window.** Tune so a deliberate two-dose log still works but an accidental
  double-press doesn't log two different pills. **Open.**
- **Eyes-free feedback fidelity.** Confirm the haptic vocabulary (logged / nothing-due / failed) is
  distinguishable on the wrist.
- **Ultra detection.** No clean public "isUltra"; rely on the system simply not offering the binding
  elsewhere, and keep guidance copy advisory.

---

## 12. Decomposition Hints (post-v1 child issues)

1. **#71a — Shared "log next pending dose" decision helper.** Extract/confirm the one function the
   widget intent and Action Button intent both call; high-risk branch returns a route, not a log.
   Fully unit-tested. (May simply formalize EPIC 08 ISSUE 04's core.)
2. **#71b — `LogNextPillIntent` + `AppShortcutsProvider` exposure** so the system can offer it as an
   Action Button option. Confirm the binding mechanism first.
3. **#71c — `ActionButtonRouter` + root-view presentation** of the high-risk press-and-hold confirm
   (reuse `NotificationActionRouter` pattern and `MarkTakenView`).
4. **#71d — Eyes-free haptic feedback** vocabulary (logged / caught-up / failed) + post-log
   `reloadAllTimelines`.
5. **#71e — Ultra-only Settings hint + availability handling.**

---

## 13. Acceptance Criteria / Done-Done

- [ ] An `AppIntent` logs the **next pending maintenance dose** via `DoseEventWriter.writeDoseEvent`
      (`loggedOn: .watch`), reusing `PendingQueueSelector` — no parallel logging logic.
- [ ] For a high-risk next dose the intent **never logs**; it opens the app onto the press-and-hold
      confirm screen for that dose (parity with EPIC 08 widget).
- [ ] The non-high-risk log path is shared with (identical to) the widget intent's path.
- [ ] After a successful log: dose transferred to iPhone (non-fatal on failure),
      `WidgetCenter.shared.reloadAllTimelines()` called, confirming haptic played.
- [ ] No pending dose → no-op with distinct feedback; write failure → dose stays pending + failure
      feedback.
- [ ] Non-Ultra hardware: no crash, no dead UI; binding guidance shown only where applicable.
- [ ] No iPhone logging surface introduced; amber stays reserved for high-risk confirm.
- [ ] All new + existing tests pass (including the high-risk "must not auto-log" test);
      `pre-commit run --all-files` clean; both targets build/run on the paired simulator.
- [ ] No anti-bypass violations (no `@unchecked Sendable`, force-unwraps, or silent `try?`; transfer
      failures are logged).
- [ ] PR opens with `Refs #11` and `Closes #71`.

---

## 14. References

- `plans/SPEC.md` §6 (iPhone never logs), §7.2 (tap-through + press-and-hold), §7.5 (single-tap
  widget log via `AppIntent`), §11 Phase 7 (`AppIntent` skill callout), §12.5 (this charter).
- `CLAUDE.md` — high-risk = press-and-hold; color reserved for high-risk; watch is the logging
  surface; iPhone never logs.
- Code: `Shared/Logging/DoseEventWriter.swift`, `Shared/Queue/PendingQueueSelector.swift`,
  `Shared/Models/Medication.swift` (`isHighRisk`), `Shared/Sync/DoseEventBatchTransfer.swift`,
  `PillBreakfast Watch App Watch App/TapThroughQueue/TapThroughQueueView.swift`,
  `PillBreakfast Watch App Watch App/Bootstrap/NotificationActionRouter.swift`.
- Prior decomposition: `plans/git-issues/EPIC_08_ISSUE_04_log-next-dose-intent.md` (the widget
  intent contract this inherits), `plans/git-issues/EPIC_11_ISSUE_05_action-button-binding.md`.
- Apple: App Intents framework, `AppShortcutsProvider`, Apple Watch Ultra Action Button (WWDC 2025
  App Intents sessions).
