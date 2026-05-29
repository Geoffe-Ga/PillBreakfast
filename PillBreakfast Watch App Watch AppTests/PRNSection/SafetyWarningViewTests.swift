import Foundation
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

  @Test func constructsWithRealViolations() {
    // Non-empty so the row-building path (ViolationMessageBuilder) is wired in.
    let apap = Ingredient(name: "Acetaminophen")
    let violations: [Violation] = [
      .ceiling(ingredient: apap, current: 1500, proposed: 4500, ceiling: 4000),
      .tooSoon(ingredient: apap, lastTakenAt: Date(timeIntervalSince1970: 1_700_000_000), minInterval: 240),
    ]
    _ = SafetyWarningView(violations: violations, isHighRisk: true, onOverride: {}, onCancel: {})
  }
}
