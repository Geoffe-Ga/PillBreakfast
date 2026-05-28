@testable import PillBreakfast_Watch_App_Watch_App
import SwiftUI
import Testing

@MainActor
struct PillBreakfast_Watch_App_Watch_AppTests {
  @Test func rightNowViewConstructs() {
    _ = RightNowView()
  }

  @Test func markTakenViewConstructs() {
    _ = MarkTakenView(medicationName: "Stub Lithium 300mg")
  }
}
