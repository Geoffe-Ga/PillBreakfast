@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct SafetyWarningViewTests {
  // Smoke: the interstitial constructs for both override modes. The violation→text
  // mapping is unit-tested in the iOS target (ViolationMessageBuilderTests).
  @Test func constructsForBothOverrideModes() {
    _ = SafetyWarningView(violations: [], isHighRisk: false, onOverride: {}, onCancel: {})
    _ = SafetyWarningView(violations: [], isHighRisk: true, onOverride: {}, onCancel: {})
  }
}
