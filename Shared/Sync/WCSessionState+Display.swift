import WatchConnectivity

public extension WCSessionActivationState {
  /// Human-readable label for the placeholder UI and activation logs.
  var displayName: String {
    switch self {
    case .notActivated: "notActivated"
    case .inactive: "inactive"
    case .activated: "activated"
    @unknown default: "unknown"
    }
  }
}
