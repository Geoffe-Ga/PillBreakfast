import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import Testing
import WatchConnectivity

@MainActor
struct WatchConnectivityCoordinatorTests {
  @Test func sharedCoordinatorActivatesIdempotently() {
    let coordinator = WatchConnectivityCoordinator.shared
    coordinator.activate()
    coordinator.activate()
    // Double activation must not record an error or leave the state machine wedged.
    #expect(coordinator.lastError == nil)
  }

  @Test func activationStateDisplayNamesAreStable() {
    #expect(WCSessionActivationState.notActivated.displayName == "notActivated")
    #expect(WCSessionActivationState.inactive.displayName == "inactive")
    #expect(WCSessionActivationState.activated.displayName == "activated")
  }
}
