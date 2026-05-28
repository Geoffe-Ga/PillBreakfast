import Foundation
import os
import WatchConnectivity

/// Activates `WCSession` at launch and surfaces the activation state to SwiftUI; no payload is exchanged until EPIC 02.
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

  /// Requests activation of the default session. Safe to call repeatedly — a second call is a no-op once activation is in flight.
  public func activate() {
    guard WCSession.isSupported() else {
      logger.warning("WCSession is not supported on this device.")
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
    }
  }

  public nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    // Payload decoding lands in EPIC 02; for now we only confirm the channel delivered something.
    logger.debug("WCSession received application context.")
  }

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
      self.logger.info("WCSession deactivated; reactivating.")
    }
    // The phone can pair with a new watch; reactivate so the next device can hand off.
    // Safe to call from any thread, so it stays outside the main-actor hop.
    WCSession.default.activate()
  }
  #endif
}
