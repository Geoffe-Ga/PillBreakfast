import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PersistenceControllerTests {
  @Test func containerOpensAgainstAppGroupStoreURL() {
    let storeURL = PersistenceController.appGroupStoreURL()
    #expect(storeURL.lastPathComponent == "PillBreakfast.store")
    // Touch the singleton — if the App Group entitlement is missing the
    // initializer traps, so reaching this line means the container is live.
    _ = PersistenceController.shared.container
  }

  @Test func appGroupUserDefaultsSuiteIsWritable() throws {
    let suite = try #require(
      UserDefaults(suiteName: PersistenceController.appGroupIdentifier)
    )
    let key = "PillBreakfastSmokeTestSentinel"
    suite.set("ok", forKey: key)
    #expect(suite.string(forKey: key) == "ok")
    suite.removeObject(forKey: key)
  }
}
