import WatchConnectivity

public extension WCSessionActivationState {
  var displayName: String {
    switch self {
    case .notActivated: "notActivated"
    case .inactive: "inactive"
    case .activated: "activated"
    @unknown default: "unknown"
    }
  }
}
