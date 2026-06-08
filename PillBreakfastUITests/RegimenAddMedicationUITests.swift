import XCTest

/// Reproduction + regression guard for the crash reported when tapping the
/// "Add medication" (`+`) toolbar button on the Regimen tab.
final class RegimenAddMedicationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testTappingAddMedicationPresentsFormWithoutCrashing() {
    let app = XCUIApplication()
    app.launch()

    // First launch may auto-present the Pill Meal onboarding sheet; dismiss
    // anything covering the toolbar so the `+` is reachable.
    let add = app.buttons["Add medication"]
    if !add.waitForExistence(timeout: 10) {
      for label in ["Skip", "Not now", "Done", "Cancel"] {
        let b = app.buttons[label]
        if b.exists, b.isHittable { b.tap() }
      }
    }
    XCTAssertTrue(add.waitForExistence(timeout: 10), "Add medication toolbar button missing")
    add.tap()

    // If the app crashed back to the home screen, the form never appears and
    // the app state drops out of foreground.
    let form = app.navigationBars["New Medication"]
    XCTAssertTrue(
      form.waitForExistence(timeout: 8),
      "New Medication form did not appear — app likely crashed on add"
    )
    XCTAssertEqual(app.state, .runningForeground, "App is not running — it crashed on add")
  }
}
