## Role

You are a senior Apple-platforms engineer setting up the foundational Xcode project for PillBreakfast in a previously-empty repository. You are comfortable with Xcode 17, watchOS 26, Swift 6 strict concurrency, App Groups, and the entitlements machinery.

## Goal

Create the paired iOS + watchOS Xcode project in this repository so both targets build cleanly under Swift 6 strict concurrency, launch on a paired simulator pair, and render a placeholder `"Hello PillBreakfast"` SwiftUI view. App Group entitlement + capabilities are configured (HealthKit on iOS only; Background Modes on both) but no functionality beyond rendering the placeholder.

## Context

- **Parent epic:** #1
- **Predecessor issue(s):** none — this is the skeleton-of-skeletons. Nothing else in EPIC 01 (or any later epic) can start until this PR lands.
- **SPEC section:** `plans/SPEC.md` §10 Phase 0 (lines 397-408) and §4 Tech Stack (lines 97-110).
- **Files involved (created in this issue):**
  - `PillBreakfast.xcodeproj/` — new Xcode project, "Watch-only App with iOS Companion" template.
  - `iOSApp/` — iOS companion app target sources, including `iOSAppApp.swift` (the `@main` SwiftUI app) and `RootView.swift` with the placeholder.
  - `WatchApp Watch App/` (or whatever Xcode's template names the watch target) — watch app target sources mirroring the same shape.
  - `Shared/` — empty for now, but added to both targets per SPEC §13.
  - `PillBreakfastTests/` and `PillBreakfastWatchTests/` — empty unit test bundles with a single `testHelloWorldViewRenders` smoke test apiece.
  - `PillBreakfast.entitlements` — `com.apple.security.application-groups = ["group.com.creekmasons.pillbreakfast"]`.
- **Prior decisions (locked):**
  - Swift 6 with strict concurrency (CLAUDE.md, SPEC §4).
  - SwiftUI + `@Observable` (not `ObservableObject`).
  - App Group shared between iPhone and watch (SPEC §4, EPIC 02 will use it).
  - Bundle ID: `com.creekmasons.pillbreakfast` (iOS), `com.creekmasons.pillbreakfast.watchkitapp` (watch). Use Geoff's email domain.
- **State of the world:** the repo is greenfield. Only `plans/SPEC.md`, `CLAUDE.md`, `.swiftformat`, `.pre-commit-config.yaml`, `scripts/swiftformat_lint.sh`, `.github/workflows/*`, and these decomposition files exist. No `.xcodeproj`, no Swift sources.

## Output Format

A single PR containing:

- [ ] `PillBreakfast.xcodeproj` and the target source folders (`iOSApp/`, `WatchApp Watch App/`, `Shared/`, `PillBreakfastTests/`, `PillBreakfastWatchTests/`).
- [ ] App Group entitlement and Background Modes (Remote Notifications + Background Fetch) configured on both targets; HealthKit capability on iOS only.
- [ ] Swift 6 strict concurrency enabled on both targets (Build Settings → Swift Compiler — Language → Strict Concurrency Checking: Complete).
- [ ] Placeholder `RootView` on each target showing `"Hello PillBreakfast"` and the platform name.
- [ ] Smoke test per target — `testHelloWorldViewRenders` — using `ViewInspector` or a simple `Text(...)` assertion via `XCTAssertNoThrow(RootView())`.
- [ ] `.gitignore` entries for `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, etc.
- [ ] No code in `Shared/` yet — empty target membership only.

## Examples

`iOSApp/iOSAppApp.swift`:

```swift
import SwiftUI

@main
struct PillBreakfastApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

`iOSApp/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        VStack {
            Text("Hello PillBreakfast")
                .font(.title)
            Text("iPhone companion · placeholder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

The watch target is structurally identical with the second `Text` reading `"Watch app · placeholder"`.

## Constraints

**Scope fence:** Do not add SwiftData models, `WCSession` setup, or any product behavior beyond rendering the placeholder. Those land in EPIC_01_ISSUE_02 and EPIC_01_ISSUE_03 respectively. If you find yourself touching `Shared/Models/` or `Shared/Sync/`, stop.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

**Tracer-code invariant:** After this PR merges, both targets must build and the paired simulator pair must show "Hello PillBreakfast" on each device. If either target fails to build, you have gone outside the skeleton — revert and re-plan.

## Definition of Done (stay-green)

- [ ] `xcodebuild -scheme PillBreakfast -destination 'platform=iOS Simulator,name=iPhone 17' build test` succeeds.
- [ ] `xcodebuild -scheme 'PillBreakfast Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build test` succeeds.
- [ ] `pre-commit run --all-files` is clean — including `scripts/swiftformat_lint.sh` showing zero diffs.
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair (the tracer-code green-at-every-phase-boundary gate).
- [ ] PR opened with `Refs #1` and `Closes #EPIC_01_ISSUE_01_NUMBER`.

## Labels

`spec-decomposition`, `tracer-skeleton`, `phase-0-skeleton`.
