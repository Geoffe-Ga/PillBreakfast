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
  /// the App-lifetime ownership contract.
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
      "App Group container unavailable; MetricKit payloads will land in tmp and be lost on next launch. Verify entitlements."
    )
    return FileManager.default.temporaryDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
  }()

  /// Write payload bytes to disk under the chosen `directory`. Pure / static so
  /// it's testable without touching MetricKit and so it can run on whatever
  /// queue MetricKit chose without capturing actor-isolated state.
  // TODO(#138): truncate to the last N files per kind so the diagnostics
  // folder doesn't grow unbounded across a daily-use install.
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
      try data.write(to: url)
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
