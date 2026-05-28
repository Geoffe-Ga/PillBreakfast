@testable import PillBreakfast_Watch_App_Watch_App
import SwiftUI
import Testing

@MainActor
struct PillBreakfast_Watch_App_Watch_AppTests {
  @Test func rightNowViewConstructs() {
    _ = RightNowView()
  }

  @Test func markTakenViewConstructs() {
    _ = MarkTakenView(
      medicationName: "Stub Lithium 300mg",
      detail: "300mg · 1 tablet",
      colorHex: nil,
      onMarkTaken: {},
      onSkip: {}
    )
  }

  @Test func tapThroughQueueViewConstructs() {
    _ = TapThroughQueueView(pendingDoses: [], onFinished: {})
  }
}
