@testable import PillBreakfast
import Testing

@MainActor
struct SettingsViewTests {
  // Smoke: the view compiles and constructs. The slider's behaviour is exercised
  // through UserPreferences/UserPreferencesStore tests; richer UI assertions wait
  // for the snapshot-test pass (EPIC_04_ISSUE_05).
  @Test func constructs() {
    _ = SettingsView()
  }
}
