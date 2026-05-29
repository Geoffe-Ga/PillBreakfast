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

  // MARK: - Default snooze offset

  @Test func snoozeOffsetDefaultsToThirty() {
    #expect(UserPreferences().defaultSnoozeOffsetMinutes == 30)
  }

  @Test func keepsAllowedSnoozeOffset() {
    #expect(UserPreferences(defaultSnoozeOffsetMinutes: 45).defaultSnoozeOffsetMinutes == 45)
  }

  @Test func snapsDisallowedSnoozeOffsetToDefault() {
    // 37 isn't one of [15, 30, 45, 60, 90] — snap to the default rather than seat the
    // watch picker on an off-menu value.
    #expect(UserPreferences(defaultSnoozeOffsetMinutes: 37).defaultSnoozeOffsetMinutes == 30)
  }

  @Test func snoozeOffsetAssignmentSnaps() {
    var preferences = UserPreferences()
    preferences.defaultSnoozeOffsetMinutes = 999 // didSet should snap to the default
    #expect(preferences.defaultSnoozeOffsetMinutes == 30)
  }

  @Test func decodeMissingSnoozeOffsetDefaultsToThirty() throws {
    // A v2 snapshot's preferences have no snooze-offset key.
    let json = Data(#"{"highRiskHoldDurationSeconds": 0.5}"#.utf8)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: json)
    #expect(decoded.defaultSnoozeOffsetMinutes == 30)
  }

  @Test func decodeDisallowedSnoozeOffsetSnaps() throws {
    let json = Data(#"{"highRiskHoldDurationSeconds": 0.5, "defaultSnoozeOffsetMinutes": 7}"#.utf8)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: json)
    #expect(decoded.defaultSnoozeOffsetMinutes == 30)
  }

  @Test func snoozeOffsetCodableRoundTrip() throws {
    let preferences = UserPreferences(highRiskHoldDurationSeconds: 0.8, defaultSnoozeOffsetMinutes: 90)
    let decoded = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(preferences))
    #expect(decoded == preferences)
    #expect(decoded.defaultSnoozeOffsetMinutes == 90)
  }
}
