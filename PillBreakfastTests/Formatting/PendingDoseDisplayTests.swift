@testable import PillBreakfast
import Testing

struct PendingDoseDisplayTests {
  @Test func textNilRendersDashes() {
    #expect(PendingDoseDisplay.text(forCount: nil) == "--")
  }

  @Test func textZeroRendersCheck() {
    #expect(PendingDoseDisplay.text(forCount: 0) == "✓")
  }

  @Test func textPositiveRendersCount() {
    #expect(PendingDoseDisplay.text(forCount: 3) == "3")
  }

  @Test func hasPendingNilIsFalse() {
    #expect(PendingDoseDisplay.hasPending(nil) == false)
  }

  @Test func hasPendingZeroIsFalse() {
    #expect(PendingDoseDisplay.hasPending(0) == false)
  }

  @Test func hasPendingPositiveIsTrue() {
    #expect(PendingDoseDisplay.hasPending(1) == true)
  }
}
