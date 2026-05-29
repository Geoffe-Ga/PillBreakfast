import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct UserPreferencesTests {
  @Test func clampsBelowRange() {
    #expect(UserPreferences(highRiskHoldDurationSeconds: 0.1).highRiskHoldDurationSeconds == 0.3)
  }

  @Test func clampsAboveRange() {
    #expect(UserPreferences(highRiskHoldDurationSeconds: 5).highRiskHoldDurationSeconds == 2.0)
  }

  @Test func keepsInRangeValue() {
    #expect(UserPreferences(highRiskHoldDurationSeconds: 0.8).highRiskHoldDurationSeconds == 0.8)
  }

  @Test func assignmentClamps() {
    var preferences = UserPreferences()
    preferences.highRiskHoldDurationSeconds = 9 // didSet should clamp
    #expect(preferences.highRiskHoldDurationSeconds == 2.0)
  }

  @Test func codableRoundTrip() throws {
    let preferences = UserPreferences(highRiskHoldDurationSeconds: 1.1)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(decoded == preferences)
  }

  @Test func decodeClampsOutOfRangeValue() throws {
    // A garbled/old wire value must not reach the gesture out of range.
    let json = Data(#"{"highRiskHoldDurationSeconds": 99}"#.utf8)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: json)
    #expect(decoded.highRiskHoldDurationSeconds == 2.0)
  }
}
