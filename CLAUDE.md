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

- **`DoseEvent.totalMg` is deliberately denormalized** (= `quantity * medication.dosagePerUnitMg`). PRN running totals are queried on every watch app open; computing it through a relationship traversal causes cascading fetches on a constrained device. Keep the precomputed value.
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

No build system exists yet. Once Phase 0 lands, this section should be updated with:

- The exact Xcode scheme names for the iOS and watchOS targets
- How to run tests (single test, full suite)
- How to launch the paired simulator pair

Until then, there are no commands to run.

## Conventions Worth Preserving

- **Watch never gets logging UI on the iPhone.** Resist the temptation to add "quick log" buttons to the phone app — it dilutes the product thesis.
- **High-risk = press-and-hold.** Single-tap is fine for vitamins; lithium and anything else flagged `isHighRisk` must require the press-and-hold gesture with a visible progress ring.
- **Color is reserved for high-risk meds.** Baseline UI is monochromatic glass. Amber accent appears only on press-and-hold confirmations. Don't decorate other surfaces with color.
- **Regimen edits trigger a full notification rebuild**, not a diff. Simpler and avoids stale `UNCalendarNotificationTrigger`s.
- **Snooze is snooze-until-time**, not fixed-duration. Custom `UNNotificationAction` opens a watch `DatePicker(.hourAndMinute)`; soft warning on the fourth consecutive snooze.
