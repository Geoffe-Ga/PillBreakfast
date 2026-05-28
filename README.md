# PillBreakfast

A watch-first medication tracker for watchOS 26 + iOS 26, built with SwiftUI, SwiftData, and Liquid Glass.

## What is PillBreakfast

PillBreakfast turns a daily pill regimen into a tap-through ritual: glance, tap, done. Each prompted pill is its own page on the watch — never a checklist. The user opens the app (or the notification fires), taps a single confirmation per medication, and moves on. The iPhone exists only so the user can define the regimen once and review history with a psychiatrist; in steady state, the phone never opens.

The product has one job: **make sure the wearer knows what they have and haven't taken, with zero ambiguity, on the device that's already on their wrist.** Safety-critical doses (e.g. lithium) use a press-and-hold confirmation so they can't be logged — or double-logged — by accident.

> Full product and engineering detail lives in [`plans/SPEC.md`](plans/SPEC.md).

## Prerequisites

- **Xcode 26 or later** (ships the iOS 26 / watchOS 26 SDKs and the Liquid Glass + HealthKit Medications APIs).
- An **iOS 26 simulator** — e.g. *iPhone 17*.
- A **watchOS 26 simulator** — e.g. *Apple Watch Series 11 (46mm)*.
- [`pre-commit`](https://pre-commit.com) and [`SwiftFormat`](https://github.com/nicklockwood/SwiftFormat) (`brew install pre-commit swiftformat`) for the local quality gate.

## Quick Start

```bash
git clone git@github.com:Geoffe-Ga/PillBreakfast.git
cd PillBreakfast
open PillBreakfast.xcodeproj
# In Xcode: select the "PillBreakfast" scheme + a paired
# iPhone 17 / Apple Watch Series 11 (46mm) simulator, then ⌘R.
```

You should see `WC state: activated` on both the iPhone and the watch within ~5 seconds.

## Build

```bash
xcodebuild build -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

xcodebuild build -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

> The watch scheme name really is doubled — `PillBreakfast Watch App Watch App` — because the watch app target nests inside its container.

## Test

```bash
xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast Watch App Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=latest'
```

Tests use the Swift Testing framework. To run a single suite or test, filter without a `test` prefix:

```bash
xcodebuild test -project PillBreakfast.xcodeproj \
  -scheme 'PillBreakfast' \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:'PillBreakfastTests/PersistenceControllerTests'
```

## Pre-commit

Install the hooks once, then they run on every commit:

```bash
pip install pre-commit        # or: brew install pre-commit
brew install swiftformat
pre-commit install
```

Run the full gate manually any time:

```bash
pre-commit run --all-files
```

This runs SwiftFormat (lint mode), a secret scan, and basic file hygiene checks. Do not bypass it — fix the root cause instead.

## Where to read next

- [`plans/SPEC.md`](plans/SPEC.md) — the authoritative product + engineering spec. Read §3 first: HealthKit Medications is **read-only** for third-party apps, which is why PillBreakfast owns its own SwiftData store.
- [`CLAUDE.md`](CLAUDE.md) — conventions, locked tech-stack decisions, data-model invariants, and the Ralph build loop. Read before making architectural changes.
- [`plans/git-issues/`](plans/git-issues/) — the decomposed implementation backlog; each file is a self-contained, agent-executable issue prompt.
