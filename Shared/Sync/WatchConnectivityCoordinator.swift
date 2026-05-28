import Foundation
import os
import SwiftData
import WatchConnectivity

/// Activates `WCSession`, pushes the regimen iPhone → watch via `updateApplicationContext`, and applies inbound snapshots on the watch.
@MainActor
@Observable
public final class WatchConnectivityCoordinator: NSObject, WCSessionDelegate {
  public static let shared = WatchConnectivityCoordinator()

  public private(set) var activationState: WCSessionActivationState = .notActivated
  public private(set) var lastError: String?

  private let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "WatchConnectivity"
  )

  override private init() {
    super.init()
  }

  /// Requests activation of the default session. Re-entrant: once the session has activated the call is skipped; a rapid double-call before the delegate fires is collapsed by WCSession itself.
  public func activate() {
    guard WCSession.isSupported() else {
      logger.warning("WCSession is not supported on this device.")
      return
    }
    // The guard only blocks re-activation after activation has completed (state
    // has left .notActivated). An in-flight double-call still passes here, but
    // WCSession collapses the second activate() request gracefully.
    guard activationState == .notActivated else {
      logger.debug("WCSession already activated; skipping re-activation.")
      return
    }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    logger.info("WCSession activation requested.")
  }

  public nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let errorText = error?.localizedDescription
    Task { @MainActor in
      self.activationState = activationState
      self.lastError = errorText
      self.logger.info("WCSession activated, state=\(activationState.displayName, privacy: .public)")
      #if os(iOS)
      // On the phone, push the current regimen as soon as the session is live, so a
      // freshly launched (or relaunched) watch converges even without a manual edit.
      if activationState == .activated {
        self.pushRegimen(from: PersistenceController.shared.container.mainContext)
      }
      #endif
    }
  }

  public nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    guard let data = applicationContext["regimen"] as? Data else {
      logger.warning("Received application context without a regimen payload.")
      return
    }
    Task { @MainActor in
      do {
        let snapshot = try JSONDecoder().decode(RegimenSnapshot.self, from: data)
        try snapshot.apply(to: PersistenceController.shared.container.mainContext)
        self.logger.info("Applied regimen with \(snapshot.medications.count, privacy: .public) medications.")
      } catch {
        self.logger.error("Failed to decode/apply regimen: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  #if os(iOS)
  /// Encodes the current regimen and pushes it to the watch via `updateApplicationContext`
  /// ("latest wins"; the payload persists if the watch is offline). iPhone → watch only.
  public func pushRegimen(from context: ModelContext) {
    guard WCSession.default.activationState == .activated else {
      logger.warning("Skipping regimen push; WCSession is not activated.")
      return
    }
    do {
      let snapshot = try RegimenSnapshot.from(context: context)
      let data = try JSONEncoder().encode(snapshot)
      try WCSession.default.updateApplicationContext(["regimen": data])
      logger.info("Pushed regimen with \(snapshot.medications.count, privacy: .public) medications.")
    } catch {
      logger.error("Failed to push regimen: \(error.localizedDescription, privacy: .public)")
    }
  }
  #endif

  #if os(iOS)
  public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    Task { @MainActor in
      self.activationState = .inactive
      self.logger.info("WCSession became inactive.")
    }
  }

  public nonisolated func sessionDidDeactivate(_ session: WCSession) {
    Task { @MainActor in
      self.activationState = .notActivated
      self.logger.info("WCSession deactivated.")
      // Reactivate through self.activate() so the delegate is re-set explicitly
      // rather than assuming it stays sticky. State is .notActivated above, so
      // the guard passes; the phone hands the session off to the next watch.
      self.activate()
    }
  }
  #endif
}
