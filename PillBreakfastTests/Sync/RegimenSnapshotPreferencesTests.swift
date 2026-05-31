import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct RegimenSnapshotPreferencesTests {
  @Test func currentSchemaVersionIsFour() {
    // Bumped to 4 for Pill Meals (#191) — `pillMeals` array on the snapshot
    // and `pillMealID` on each scheduled dose. Older payloads decode by
    // defaulting these to `[]` / `nil`.
    #expect(RegimenSnapshot.currentSchemaVersion == 4)
  }

  @Test func roundTripCarriesPreferences() throws {
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [],
      preferences: UserPreferences(highRiskHoldDurationSeconds: 1.3, defaultSnoozeOffsetMinutes: 60)
    )
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(decoded.preferences.highRiskHoldDurationSeconds == 1.3)
    #expect(decoded.preferences.defaultSnoozeOffsetMinutes == 60)
    #expect(decoded == snapshot)
  }

  @Test func decodesLegacyV1SnapshotWithDefaultPreferences() throws {
    // A v1 payload (a not-yet-updated iPhone) predates `preferences` entirely;
    // it must decode without crashing and default to 0.5s rather than fail.
    let json = Data(#"{"schemaVersion":1,"ingredients":[],"medications":[]}"#.utf8)
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: json)
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.preferences == UserPreferences())
    #expect(decoded.preferences.highRiskHoldDurationSeconds == UserPreferences.defaultHoldDuration)
  }

  @Test func decodesLegacyV2SnapshotWithDefaultSnoozeOffset() throws {
    // A v2 payload carries `preferences` but no snooze offset (added in v3); the
    // offset must default to 30 without dropping the hold duration it does carry.
    let json = Data(#"""
    {"schemaVersion":2,"ingredients":[],"medications":[],"preferences":{"highRiskHoldDurationSeconds":0.8}}
    """#.utf8)
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: json)
    #expect(decoded.schemaVersion == 2)
    #expect(decoded.preferences.highRiskHoldDurationSeconds == 0.8)
    #expect(decoded.preferences.defaultSnoozeOffsetMinutes == UserPreferences.defaultSnoozeOffsetMinutes)
  }
}
