@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct PRNListViewTests {
  // Smoke: the watch PRN list constructs. Row content is driven by the shared
  // PRNRowSummaryBuilder, which is unit-tested in the iOS target.
  @Test func constructs() {
    _ = PRNListView()
  }
}
