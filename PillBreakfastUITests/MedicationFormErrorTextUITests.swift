import XCTest

/// Guards that validation-error text on the Add medication form renders with a
/// non-zero frame at default Dynamic Type (issue #103 — error-text legibility).
final class MedicationFormErrorTextUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testValidationErrorTextIsVisible() {
    let app = XCUIApplication()
    app.launch()

    // Dismiss any first-launch sheet covering the toolbar.
    let add = app.buttons["Add medication"]
    if !add.waitForExistence(timeout: 10) {
      for label in ["Skip", "Not now", "Done", "Cancel"] {
        let b = app.buttons[label]
        if b.exists, b.isHittable { b.tap() }
      }
    }
    XCTAssertTrue(add.waitForExistence(timeout: 10), "Add medication button missing")
    add.tap()

    let name = app.textFields["Name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5), "Name field missing")
    name.tap()
    name.typeText("A") // any edit flips hasInteracted → the error section appears

    // The ingredient is still unselected, so this validation error is shown.
    let error = app.staticTexts["Select an ingredient."]
    XCTAssertTrue(error.waitForExistence(timeout: 5), "Validation error text not shown")
    XCTAssertGreaterThan(error.frame.height, 0, "Error text has zero height — clipped/illegible")
  }
}
