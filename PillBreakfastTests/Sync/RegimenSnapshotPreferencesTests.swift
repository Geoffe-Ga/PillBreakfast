import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct RegimenSnapshotPreferencesTests {
  @Test func currentSchemaVersionIsTwo() {
    #expect(RegimenSnapshot.currentSchemaVersion == 2)
  }

  @Test func roundTripCarriesPreferences() throws {
    let snapshot = RegimenSnapshot(
      ingredients: [],
      medications: [],
      preferences: UserPreferences(highRiskHoldDurationSeconds: 1.3)
    )
    let decoded = try JSONDecoder().decode(RegimenSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(decoded.preferences.highRiskHoldDurationSeconds == 1.3)
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
}
