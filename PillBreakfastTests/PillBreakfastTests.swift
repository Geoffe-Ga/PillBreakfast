@testable import PillBreakfast
import SwiftUI
import Testing

@MainActor
struct PillBreakfastTests {
  @Test func mainTabViewConstructs() {
    _ = MainTabView()
  }

  @Test func regimenListViewConstructs() {
    _ = RegimenListView()
  }
}
