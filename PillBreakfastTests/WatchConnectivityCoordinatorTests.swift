import Foundation
@testable import PillBreakfast
import Testing
import WatchConnectivity

@MainActor
struct WatchConnectivityCoordinatorTests {
  @Test func sharedCoordinatorActivatesIdempotently() {
    let coordinator = WatchConnectivityCoordinator.shared
    coordinator.activate()
    coordinator.activate()
    #expect(WatchConnectivityCoordinator.shared === coordinator)
  }

  @Test func activationStateDisplayNamesAreStable() {
    #expect(WCSessionActivationState.notActivated.displayName == "notActivated")
    #expect(WCSessionActivationState.inactive.displayName == "inactive")
    #expect(WCSessionActivationState.activated.displayName == "activated")
  }
}
