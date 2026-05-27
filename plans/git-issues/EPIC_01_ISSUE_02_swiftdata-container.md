## Role

You are a senior Apple-platforms engineer wiring the persistence layer for PillBreakfast. You are comfortable with SwiftData's `ModelContainer` configuration, App Group container URLs, and Swift 6 strict concurrency around shared persistence.

## Goal

Add a `PersistenceController` in `Shared/` that opens a SwiftData `ModelContainer` against the App Group container URL on both targets. The schema is intentionally empty (no `@Model` classes yet — those land in EPIC 02). The controller exposes a `ModelContainer` and a `ModelContext` to the SwiftUI environment of each app.

## Context

- **Parent epic:** #1
- **Predecessor issue(s):** #EPIC_01_ISSUE_01_NUMBER (Xcode project skeleton must exist).
- **SPEC section:** `plans/SPEC.md` §4 Tech Stack (SwiftData line) and §10 Phase 0 ("Set up SwiftData container shared by both targets via app group").
- **Files involved:**
  - `Shared/Persistence/PersistenceController.swift` — the controller, exposing `static let shared` and a method to derive the App Group URL.
  - `iOSApp/iOSAppApp.swift` — injects `.modelContainer(PersistenceController.shared.container)` into the scene.
  - `WatchApp Watch App/WatchApp.swift` (or equivalent) — same injection on the watch.
  - `PillBreakfastTests/PersistenceControllerTests.swift` — smoke test that the container opens and a sentinel UserDefaults key persists in the App Group's user defaults suite.
- **Prior decisions (locked):**
  - App Group identifier: `group.com.creekmasons.pillbreakfast` (from EPIC_01_ISSUE_01).
  - SwiftData is the persistence layer (SPEC §4); no Core Data fallback.
  - Schema is empty in this issue; EPIC 02 adds `Ingredient`, `Medication`, etc.
- **State of the world:** EPIC_01_ISSUE_01 has landed. Both targets build and render the placeholder view. There is no SwiftData code anywhere yet.

## Output Format

A single PR containing:

- [ ] `Shared/Persistence/PersistenceController.swift` with the documented API below.
- [ ] Scene-level `.modelContainer(...)` injection on both iOS and watchOS targets.
- [ ] `PersistenceControllerTests` smoke test on iOS confirming the container opens and the App Group user defaults suite is writable.
- [ ] Matching test on the watch target.
- [ ] Brief docstring on `PersistenceController.shared` explaining the App Group URL derivation and that the schema is intentionally empty in this issue.

## Examples

`Shared/Persistence/PersistenceController.swift`:

```swift
import Foundation
import SwiftData

@MainActor
public final class PersistenceController: Sendable {
    public static let shared = PersistenceController()

    public let container: ModelContainer

    private init() {
        let url = Self.appGroupStoreURL()
        let config = ModelConfiguration(url: url)
        do {
            // Schema is empty for now — EPIC 02 adds @Model classes.
            self.container = try ModelContainer(for: Schema([]), configurations: config)
        } catch {
            fatalError("Failed to open SwiftData container at \(url): \(error)")
        }
    }

    public static func appGroupStoreURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.creekmasons.pillbreakfast"
        ) else {
            fatalError("App Group container is unavailable. Check entitlements.")
        }
        return containerURL.appendingPathComponent("PillBreakfast.store")
    }
}
```

Smoke test:

```swift
@MainActor
final class PersistenceControllerTests: XCTestCase {
    func testContainerOpensAndAppGroupIsWritable() throws {
        let controller = PersistenceController.shared
        XCTAssertNotNil(controller.container)

        let suite = UserDefaults(suiteName: "group.com.creekmasons.pillbreakfast")
        XCTAssertNotNil(suite)
        suite?.set("ok", forKey: "PillBreakfastSentinel")
        XCTAssertEqual(suite?.string(forKey: "PillBreakfastSentinel"), "ok")
    }
}
```

## Constraints

**Scope fence:** Do not add any `@Model` classes — those are EPIC_02_ISSUE_01. Do not add `WCSession` code — that's EPIC_01_ISSUE_03. Do not add real product data. If the smoke test needs more than "the container opens," you have gone outside scope.

**Anti-bypass (verbatim, non-negotiable):**

> No bypasses. Do not add `// swiftlint:disable`, `// swiftformat:disable`, `@available(*, deprecated)` shims to hide warnings, force-unwraps to silence the optional checker, `@unchecked Sendable` to silence Swift 6 concurrency, or `try?` that swallows errors silently. Fix the root cause. The only exception is the documented 4-line escape hatch (third-party-SDK bug / OS-version compat / benchmarked-perf / generated code) with a review date. See `max-quality-no-shortcuts`.

The `fatalError` in `init` is intentional: a missing App Group entitlement is a configuration bug we want to fail loudly at launch, not paper over with optional unwrapping. That is the documented exception.

**Tracer-code invariant:** Both targets must still build and run; the placeholder views from EPIC_01_ISSUE_01 must continue to render.

## Definition of Done (stay-green)

- [ ] All new and existing tests pass (`xcodebuild test` for both schemes).
- [ ] `pre-commit run --all-files` is clean.
- [ ] SwiftFormat clean (`scripts/swiftformat_lint.sh`).
- [ ] App builds and runs on the paired iPhone + watchOS simulator pair.
- [ ] PR opened with `Refs #1` and `Closes #EPIC_01_ISSUE_02_NUMBER`.

## Labels

`spec-decomposition`, `core`, `phase-0-skeleton`.
