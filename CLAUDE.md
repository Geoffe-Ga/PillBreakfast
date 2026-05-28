# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current State

This is a **greenfield repository**. There is no Xcode project, no source code, and no build/test infrastructure yet. The only artifact is `plans/SPEC.md`, the product and engineering specification. The first executable work is **Phase 0** (Skeleton) per `plans/SPEC.md` §10 — create the paired iOS + watchOS Xcode targets.

`plans/SPEC.md` is the authoritative reference. Read it before making any architectural decisions; it captures research that is not derivable from code (especially the HealthKit constraint below).

## What PillBreakfast Is

A watch-first medication tracker for watchOS 26 + iOS 26. Geoff takes ~12 pills/day across maintenance and PRN regimens, including safety-critical doses (lithium) that must not be double-taken. The product's one job: zero-ambiguity tap-through logging on the wrist.

- **Watch is the primary surface.** All dose logging happens on the watch. One pill per screen, single confirm tap (press-and-hold for high-risk meds).
- **iPhone is setup + review only.** It must **never** show "take pills now" prompts. Regimen editing, history, PDF export — that's it.

## Critical Architecture Constraint: HealthKit Is Read-Only

This is the single most important fact about the codebase and it is **not obvious from the API surface**:

> Third-party apps **cannot write** to Apple Health Medications. `HKMedicationDoseEvent` is read-only for third-party apps. Confirmed by Apple DTS.

Additionally, the HealthKit Medications API is **iOS/iPadOS/visionOS only — not watchOS**. Medication objects must be queried on the iPhone and synced to the watch.

**Consequence:** PillBreakfast owns its own SwiftData store as the source of truth. Apple Health is treated as a *one-way import source for onboarding only*. Do not propose architectures where Health is the authority or where the watch reads medications directly from HealthKit — both are blocked by Apple. See SPEC §3 for the alternatives that were considered and rejected.

## Tech Stack (Locked Decisions)

| Layer | Choice |
| --- | --- |
| OS targets | watchOS 26, iOS 26 (required for Liquid Glass + HealthKit Medications) |
| Language | Swift 6 with **strict concurrency** (Sendable, actor isolation) |
| UI | SwiftUI, `@Observable` (not `ObservableObject`) |
| Persistence | SwiftData, shared via app group |
| Phone↔watch sync | WatchConnectivity (`WCSession`) — `updateApplicationContext` for regimen, file transfer for history |
| Notifications | UserNotifications, scheduled **on the watch directly** so it works when the phone is off |
| Design | Liquid Glass (`.glassEffect()` / Material APIs) |

## Data Model Conventions

The SwiftData schema is defined in SPEC §5. Two non-obvious conventions to preserve:

- **`DoseEvent.ingredientAmounts` is a deliberately denormalized snapshot** (an `[LoggedIngredientAmount]`, each carrying `ingredientID` / `ingredientName` / `totalMg = quantity × component.dosagePerUnitMg`). PRN running totals are queried on every watch app open; computing them through a relationship traversal causes cascading fetches on a constrained device. The snapshot is filled at log time and is **never** recomputed from the live `medication.components` — editing a product's components later must not rewrite history. (SPEC §5.2/§5.3 supersede the earlier single-scalar `DoseEvent.totalMg` sketch; the per-ingredient array is the source of truth because safety ceilings are per-ingredient.)
- **`Medication.healthKitConceptID`** is populated *only* when a med was imported from Health. It's a link for future readback enrichment, not a write channel.

## Plan Files & Tracer-Code Workflow

Work is sequenced into phases (SPEC §10), executed tracer-code style: wire the skeleton end-to-end first, then iteratively replace stubs. **At every phase boundary the app must build and run on a paired iPhone + watch simulator.**

Each phase gets its own plan file:

- Location: `plans/` (note: SPEC §13 says `plan/` — the actual directory is `plans/`; prefer the existing name unless instructed otherwise)
- Naming: `YYYY-MM-DD_PHASE_N_<NAME>.md` (e.g. `2026-05-15_PHASE_0_SKELETON.md`)
- Structure: 6-component prompt (Role / Goal / Context / Format / Examples / Constraints)
- Today's date for new plan files: 2026-05-15

When asked to start a phase, generate its plan file first and align before writing code.

## Build / Test / Run

Requires **Xcode 26+** (ships the iOS 26 / watchOS 26 SDKs). The project is `PillBreakfast.xcodeproj`; there is no workspace and no Swift package manifest (Phase 0 — likely revisited when `Shared/` is extracted into its own package).

Schemes (exact names — note the watch scheme is doubled):

- `PillBreakfast` — iOS companion target (+ `PillBreakfastTests`, `PillBreakfastUITests`).
- `PillBreakfast Watch App Watch App` — watchOS target (+ its `…Tests` / `…UITests`).

Build both targets:

```bash
xcodebuild build -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

xcodebuild build -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

Run the full test suite (swap `build` for `test`):

```bash
xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

Run a single test or suite (Swift Testing — filter by suite or test name, no `test` prefix):

```bash
xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:'PillBreakfastTests/PersistenceControllerTests'
```

Lint / format / secret-scan gate (must be clean before every commit):

```bash
pre-commit run --all-files
```

Launch the paired simulator pair from Xcode's toolbar device picker: pick any **iPhone 17** paired with any **Apple Watch Series 11 (46mm)**, then ⌘R. Both apps should show `WC state: activated` within ~5 seconds.

## The Ralph Loop

PillBreakfast is built by a **caffeinated, local-session Ralph Wiggum loop**. The implementation backlog is filed as GitHub issues; each issue body is a self-contained 6-component prompt. The loop runs in a long-lived Claude Code session on a Mac, kept awake by `caffeinate -d -i`, and woken on every relevant PR event by an MCP subscription. The cloud is a participant, not the engine.

### Topology

1. **Local engine**: a `/loop /ralph-tick` session in a `caffeinate`d terminal. The model self-paces via `ScheduleWakeup` and is woken early by `mcp__github__subscribe_pr_activity` events. `/ralph-tick` is re-entrant — each tick reads `scripts/ralph/state.json` and the open-PR state, then does one atomic action.
2. **Inner loop in the cloud** stays in place:
   - `ci.yml` runs on each push (pre-commit + Swift format/build once Phase 0 lands).
   - `claude-code-review.yml` leaves a `Verdict:` comment (LGTM / CHANGES_REQUESTED / COMMENTS) on each PR.
   - `iteration-trigger.yml` watches for CI completion + the verdict comment. It posts a marker comment that **wakes the local session via PR-activity subscription**. If `LGTM` + fully green, it also squash-merges (using `GEOFFE_GA_PAT` so the merge fires downstream events).
3. **Local session's reaction to each wake**:
   - **PR merged** → record completion, increment `state.completed_since_groom`, pick next issue, open PR, subscribe, end turn.
   - **`CHANGES_REQUESTED` / `COMMENTS`** → run the `address-feedback` skill, push fixes, re-subscribe, end turn.
   - **CI failed** → run the `ci-debugging` skill, fix, push, re-subscribe, end turn.
   - **In-flight, no verdict yet** → re-subscribe via `await-claude-review`, end turn.
4. **Groom gate**: every `state.groom_interval` (default **10**) merged issues, the next tick invokes the `/backlog-grooming` skill before picking the next issue. The counter resets on completion.
5. **Termination**: when `scripts/ralph/pick-next.sh` returns nothing and no PR is in flight, the tick announces "Backlog drained" and stops `/loop`.

### Starting and stopping

```bash
# Start the loop (will run until backlog drained or Ctrl-C).
caffeinate -d -i claude --add-dir "$(pwd)"
# Inside the session:
/loop /ralph-tick
```

To stop: Ctrl-C in the terminal, or send `/loop --stop` from within the session.

### Controls

| What | How |
| --- | --- |
| Pause new picks | Touch `scripts/ralph/.paused` (the tick treats it as "do nothing this tick"). Remove to resume. |
| Pause auto-merge only | Set repo variable `RALPH_AUTO_MERGE_DISABLED=true` (inner loop still cycles, you merge by hand). |
| Skip auto-merge for one PR | Add label `do-not-auto-merge` to the PR. |
| Reset the groom counter | Edit `scripts/ralph/state.json` → `"completed_since_groom": 0`. |
| Force a groom this tick | Edit `state.json` → set `"completed_since_groom"` ≥ `"groom_interval"`. |
| Skip a specific issue | Add label `needs-spec` to it; the picker will pass it over. |
| Use the cloud as a backup | `Actions → "Ralph (next issue) [manual fallback]" → Run workflow`. Only do this when the local session is offline; running both at once will race. |
| Stop the inner loop on a hot PR | Close the PR, or add the `do-not-auto-merge` label. |
| Cap on inner-loop runaway | `iteration-trigger.yml` self-caps at 10 nudges per PR. |

### Files

- `.claude/commands/ralph-tick.md` — the per-tick orchestrator (the `/ralph-tick` slash command).
- `scripts/ralph/PROMPT.md` — the per-issue worker contract referenced by `/ralph-tick`.
- `scripts/ralph/pick-next.sh` — picker (lowest-numbered open child issue, skips `epic` / `future-work` / `needs-spec` / issues already in-flight).
- `scripts/ralph/state.json` — Ralph's notebook: counter, last-completed issue, last-groom timestamp.
- `.github/workflows/iteration-trigger.yml` — inner-loop cadence + auto-merge gate (also the wake source).
- `.github/workflows/ralph-next.yml` — manual cloud fallback only (triggers reduced to `workflow_dispatch`).

### Required secrets and variables

- Secret `CLAUDE_CODE_OAUTH_TOKEN` — used by the inner-loop reviewer and the cloud fallback.
- Secret `GEOFFE_GA_PAT` — PAT with `repo` scope; lets the iteration-trigger's comments and merges fire downstream events and wake the local subscription.
- Variable `RALPH_AUTO_MERGE_DISABLED` (optional; `true` keeps inner loop running but disables auto-merge).

### Bootstrap

Issue **#12** (the paired Xcode project skeleton) is **not** Ralph's job — pbxproj binary plists, signing, capabilities, and the App Group are easier to set up by hand once than to debug through several Ralph ticks. Land #12 manually, merge it, then start the loop. Ralph picks up at #13.

### Known caveats

- **SwiftFormat in the local environment**: `pre-commit run --all-files` invokes `scripts/swiftformat_lint.sh`. SwiftFormat is already installed via Homebrew on this Mac (`/opt/homebrew/bin/swiftformat`), so the hook runs. If you ever move the loop to a different machine, install SwiftFormat first or the Swift hook will block every tick.
- **MCP GitHub server** must be configured for the local session for `mcp__github__subscribe_pr_activity` to work; otherwise the loop falls back to scheduled wakeups (`ScheduleWakeup` ~30 min) and runs slower but still terminates.
- **Context drift in long sessions**: `/loop /ralph-tick` runs in one long session. The harness compacts as needed, but `/ralph-tick` is deliberately re-entrant — it never trusts in-memory state. If you suspect drift, Ctrl-C and restart; state lives entirely on disk.

## Conventions Worth Preserving

- **Watch never gets logging UI on the iPhone.** Resist the temptation to add "quick log" buttons to the phone app — it dilutes the product thesis.
- **High-risk = press-and-hold.** Single-tap is fine for vitamins; lithium and anything else flagged `isHighRisk` must require the press-and-hold gesture with a visible progress ring.
- **Color is reserved for high-risk meds.** Baseline UI is monochromatic glass. Amber accent appears only on press-and-hold confirmations. Don't decorate other surfaces with color.
- **Regimen edits trigger a full notification rebuild**, not a diff. Simpler and avoids stale `UNCalendarNotificationTrigger`s.
- **Snooze is snooze-until-time**, not fixed-duration. Custom `UNNotificationAction` opens a watch `DatePicker(.hourAndMinute)`; soft warning on the fourth consecutive snooze.
