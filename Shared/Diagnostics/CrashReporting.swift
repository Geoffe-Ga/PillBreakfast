import Foundation
import os
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

  /// Override-point for tests: the directory the persistence pass writes into.
  /// Defaults to the App Group's `Diagnostics/` folder. Default visibility
  /// (`internal`) is intentional — tests reach it via `@testable import`.
  let directory: URL

  public nonisolated init(directory: URL = CrashReporting.defaultDiagnosticsDirectory) {
    self.directory = directory
    super.init()
  }

  /// Register with `MXMetricManager` so payloads start arriving. Called once
  /// from the owning App's init. The instance lives for the process lifetime
  /// — no `deinit { stop() }` because `MXMetricManager.remove` has been
  /// observed to crash in parallel-test harnesses when called on subscribers
  /// added across concurrent test cases.
  public nonisolated func start() {
    #if canImport(MetricKit)
    MXMetricManager.shared.add(self)
    #endif
  }

  /// Unregister; provided for explicit teardown but the App-lifetime
  /// ownership pattern is the documented contract.
  public nonisolated func stop() {
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
