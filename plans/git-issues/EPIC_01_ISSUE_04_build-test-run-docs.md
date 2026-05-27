## Role

You are a senior developer responsible for the onboarding experience of any engineer (human or agent) who clones PillBreakfast for the first time. You write documentation that is concise, copy-pasteable, and immediately verifiable.

## Goal

Replace CLAUDE.md's "Build / Test / Run" stub with real commands for the project now that it exists, and add a top-level `README.md` that orients a new contributor in under five minutes. After this PR, an engineer who has just cloned the repo can build, test, and launch the paired simulator pair by copy-pasting commands from the README.

## Context

- **Parent epic:** #1
- **Predecessor issue(s):** #EPIC_01_ISSUE_01_NUMBER, #EPIC_01_ISSUE_02_NUMBER, #EPIC_01_ISSUE_03_NUMBER — all skeleton scaffolding must be present so we have real scheme names and real commands to document.
- **SPEC section:** `plans/SPEC.md` §13 (Recommended layout) and CLAUDE.md "Build / Test / Run" (currently a placeholder).
- **Files involved:**
  - `README.md` (new, top-level) — project overview, quick start, contributor pointers.
  - `CLAUDE.md` — replace the "Build / Test / Run" stub with real commands.
- **Prior decisions (locked):**
  - The actual plans directory is `plans/`, not `plan/`. SPEC §13 says `plan/`; CLAUDE.md notes the deviation. The README must reflect the real directory name.
  - Scheme names come from EPIC_01_ISSUE_01 (likely `PillBreakfast` and `PillBreakfast Watch App`).
- **State of the world:** the project skeleton exists, both targets build, `WCSession` activates on launch. There is no README at the repo root.

## Output Format

A single PR containing:

- [ ] `README.md` with sections: What is PillBreakfast (3-5 sentences quoting SPEC §1 vision); Prerequisites (Xcode 17, watchOS 26 simulator, paired iPhone 17 simulator); Quick Start (clone + open `.xcodeproj` + run scheme); Build commands; Test commands; Pre-commit setup; Where to read next (SPEC + CLAUDE.md + `plans/git-issues/`).
- [ ] `CLAUDE.md` "Build / Test / Run" section rewritten with the real scheme names, the exact `xcodebuild` commands, the paired-simulator boot incantation (`xcrun simctl boot` or "use the Xcode toolbar pair").
- [ ] No changes to any code file. Documentation only.

## Examples

`README.md` Quick Start excerpt:

```markdown
## Quick Start

```bash
git clone git@github.com:creekmasons/PillBreakfast.git
cd PillBreakfast
open PillBreakfast.xcodeproj
# In Xcode: select the "PillBreakfast" scheme + the paired
# iPhone 17 / Apple Watch Series 11 simulator, then ⌘R.
```

You should see "Hello PillBreakfast · WC state: activated" on both
devices within ~5 seconds.
```

CLAUDE.md "Build / Test / Run" replacement:

```markdown
## Build / Test / Run

Schemes:

- `PillBreakfast` — iOS companion target.
- `PillBreakfast Watch App` — watchOS target.

Run the full test suite:

```bash
xcodebuild test \
  -scheme PillBreakfast \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild test \
  -scheme 'PillBreakfast Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

To run a single test: append `-only-testing:PillBreakfastTests/PersistenceControllerTests/testContainerOpensAndAppGroupIsWritable`.

Launch the paired simulator pair from Xcode's toolbar device picker; pick any iPhone 17 paired with any Apple Watch Series 11 (46mm).
```

## Constraints

**Scope fence:** No code changes. No new scripts. No new dependencies. If you find yourself editing anything in `iOSApp/`, `WatchApp Watch App/`, or `Shared/`, stop.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** Documentation-only PR; nothing should regress. Both schemes still build and test.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean — markdown linters, if configured, must pass.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #1` and `Closes #EPIC_01_ISSUE_04_NUMBER`.

## Labels

`spec-decomposition`, `docs`, `phase-0-skeleton`.
