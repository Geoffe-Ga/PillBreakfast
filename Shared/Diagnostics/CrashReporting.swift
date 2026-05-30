import Foundation
import os

// `canImport` instead of `os(iOS) || os(watchOS)` so the type still compiles
// on a macOS test host that builds the Shared module without an iOS SDK
// available. On the locked iOS 26 / watchOS 26 deployment targets MetricKit
// is always importable; the guard is purely a build-environment defense.
#if canImport(MetricKit)
import MetricKit
#endif

/// MetricKit-driven crash and diagnostic capture (SPEC §10 Phase 9). Subscribes
/// to `MXMetricManager`, writes each received payload's `jsonRepresentation()`
/// to the App Group's private `Diagnostics/` subdirectory. No third-party SDK,
/// no network egress.
///
/// See `plans/decisions/2026-05-29_crash-reporting.md` for the trade-off
/// analysis that led to MetricKit over Crashlytics / Sentry.
///
/// `final` with no mutable state and protocol callbacks marked `nonisolated`
/// so MetricKit can dispatch from its internal queue without crossing actor
/// boundaries. The owning App holds one instance for the process lifetime;
/// the singleton lives on the heap and never moves between actors.
public final class CrashReporting: NSObject {
  /// `nonisolated` because the protocol callbacks (`didReceive`) are themselves
  /// nonisolated; they can't reach a MainActor-isolated static under the
  /// module's default-MainActor isolation.
  private nonisolated static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "CrashReporting"
  )

  /// Process-wide singleton that registers with `MXMetricManager` exactly
  /// once. `@main App` is a value type and SwiftUI is documented to allow
  /// multiple constructions of the App struct, so an instance-per-init
  /// pattern risks adding duplicate subscribers; the lazy `static let`
  /// initializer runs once for the process, so `start()` is called at most
  /// once. The App's init just references `Self.shared` to force the lazy.
  public static let shared: CrashReporting = {
    let instance = CrashReporting()
    instance.start()
    return instance
  }()

  /// Override-point for tests: the directory the persistence pass writes into.
  /// Defaults to the App Group's `Diagnostics/` folder. Default visibility
  /// (`internal`) is intentional — tests reach it via `@testable import`.
  let directory: URL

  public nonisolated init(directory: URL = CrashReporting.defaultDiagnosticsDirectory) {
    self.directory = directory
    super.init()
  }

  /// Register with `MXMetricManager`. The only production caller is the lazy
  /// `shared` initializer, which guarantees a single invocation —
  /// `internal` (not `public`) so external callers can't accidentally
  /// double-subscribe by calling `CrashReporting.shared.start()` again.
  nonisolated func start() {
    #if canImport(MetricKit)
    MXMetricManager.shared.add(self)
    #endif
  }

  /// Unregister; provided for explicit teardown. `internal` so external
  /// callers can't tear down the singleton's subscription out from under
  /// the App-lifetime ownership contract. No production caller by design —
  /// the App-lifetime instance never stops; this stays as a test escape
  /// hatch and a documentation surface for the inverse of `start()`.
  nonisolated func stop() {
    #if canImport(MetricKit)
    MXMetricManager.shared.remove(self)
    #endif
  }

  /// Computed once on first access — App Group container lookup is cheap, but
  /// computing it lazily lets the tests inject their own override.
  ///
  /// If the App Group entitlement is misconfigured, `containerURL(for:)`
  /// returns `nil` and we fall back to the process temp directory so the
  /// subscriber still works in development — but the fallback is logged at
  /// `.fault` level since payloads written to `tmp/` are lost on next launch
  /// and that failure is otherwise invisible in the field.
  public nonisolated static let defaultDiagnosticsDirectory: URL = {
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: PersistenceController.appGroupIdentifier
    ) {
      return containerURL.appendingPathComponent("Diagnostics", isDirectory: true)
    }
    logger.fault(
      "App Group container unavailable; MetricKit payloads will land in tmp and may be lost at OS discretion. Verify entitlements."
    )
    return FileManager.default.temporaryDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
  }()

  /// Retention budget per kind. MetricKit delivers at most one batch per day,
  /// so 30 keeps roughly a month of history per kind — long enough for the
  /// EPIC 10 soak window and for normal post-mortem investigations without
  /// the App Group container growing unbounded across a daily-use install.
  ///
  /// `nonisolated` is load-bearing here, not decorative: under the module's
  /// `-default-isolation MainActor` setting, `final class CrashReporting`
  /// inherits MainActor — so without the annotation this constant is
  /// MainActor-isolated and can't appear as a default arg in `prune(...)`
  /// (which is itself `nonisolated`). Dropping the annotation reintroduces
  /// "main actor-isolated default value in a nonisolated context" at build.
  public nonisolated static let retainPerKind: Int = 30

  /// Write payload bytes to disk under the chosen `directory`, then truncate
  /// the `<kind>-…` files there to the most recent `retainPerKind`. Pure /
  /// static so it's testable without touching MetricKit and so it can run on
  /// whatever queue MetricKit chose without capturing actor-isolated state.
  ///
  /// Throws only when directory creation fails — without a writable directory
  /// nothing else can succeed. Per-file write failures are best-effort: the
  /// loop logs and keeps going so a disk-full mid-batch doesn't silently
  /// discard payloads 3-5 of 5. For crash diagnostics, partial capture beats
  /// all-or-nothing.
  nonisolated static func persist(
    payloads: [Data],
    kind: String,
    in directory: URL,
    now: Date = .now
  ) throws {
    if !payloads.isEmpty {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let stamp = Int(now.timeIntervalSince1970)
    for data in payloads {
      let filename = "\(kind)-\(stamp)-\(UUID().uuidString).json"
      let url = directory.appendingPathComponent(filename)
      do {
        try data.write(to: url)
      } catch {
        logger.error(
          "Failed to write \(kind, privacy: .public) payload: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
    // Truncate after each successful batch write — the just-written files
    // are guaranteed to be the newest, so the prune keeps them and evicts
    // the oldest until we're at `retainPerKind`.
    if !payloads.isEmpty {
      prune(kind: kind, in: directory)
    }
  }

  /// Delete `<kind>-…` files beyond `retainCount` under `directory`. Sorts
  /// lexicographically — chronologically, because filenames embed a
  /// fixed-width unix stamp (`persist` writes `Int(now.timeIntervalSince1970)`,
  /// which stays 10 digits until year 2286). Files that don't match the
  /// kind prefix are left alone; the prune is intentionally scoped to what
  /// `persist` produces.
  ///
  /// Internal so tests can exercise the truncation independently of a
  /// write; production callers are expected to go through `persist`, which
  /// invokes this on the just-written kind.
  ///
  /// Not file-coordinated: MetricKit delivers at most one batch per day,
  /// so concurrent `prune` calls aren't expected. If that contract ever
  /// changes (e.g. a second writer in `Diagnostics/`), this needs a
  /// `NSFileCoordinator` or process-wide lock around the read+delete.
  nonisolated static func prune(
    kind: String,
    in directory: URL,
    retainCount: Int = retainPerKind
  ) {
    // First-launch case: the directory hasn't been created yet (no payload
    // has ever been written). That's a clean no-op, not a failure — split
    // it from the catch so unexpected `contentsOfDirectory` failures
    // (permissions, sandbox, corrupted entries) surface at `.warning`
    // rather than getting silently swallowed alongside the expected path.
    if !FileManager.default.fileExists(atPath: directory.path) { return }
    let contents: [String]
    do {
      contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    } catch {
      logger.warning(
        "prune skipped — could not list \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return
    }
    let prefix = "\(kind)-"
    let matching = contents
      .filter { $0.hasPrefix(prefix) }
      .sorted(by: >) // descending → newest first
    if matching.count <= retainCount { return }
    for stale in matching.dropFirst(retainCount) {
      let url = directory.appendingPathComponent(stale)
      do {
        try FileManager.default.removeItem(at: url)
      } catch {
        logger.warning(
          "Failed to prune stale \(kind, privacy: .public) payload \(stale, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}

#if canImport(MetricKit)
extension CrashReporting: MXMetricManagerSubscriber {
  /// Called by MetricKit on its internal queue. Writes the payloads off the
  /// callback queue so a slow filesystem can't back-pressure MetricKit's
  /// scheduler. Errors land in OSLog — there's no surface to surface them on.
  public nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
    let data = payloads.map { $0.jsonRepresentation() }
    let target = directory
    Task.detached(priority: .utility) {
      do {
        try CrashReporting.persist(payloads: data, kind: "metric", in: target)
      } catch {
        CrashReporting.logger.error(
          "Failed to persist MetricKit metric payload: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  public nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
    let data = payloads.map { $0.jsonRepresentation() }
    let target = directory
    Task.detached(priority: .utility) {
      do {
        try CrashReporting.persist(payloads: data, kind: "diagnostic", in: target)
      } catch {
        CrashReporting.logger.error(
          "Failed to persist MetricKit diagnostic payload: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}
#endif
