import XCTest

/// Memory-RCA repro driver (investigation only — not product behaviour).
///
/// Drives the two interaction symptoms the owner reported on the iOS app:
///   1. History tab appear → auto-runs `PDFExporter.exportLast30Days` via `.task`.
///   2. Add-medication form → rapid typing in the Name field (re-render storm test).
///
/// The test inserts deliberate dwell windows so an external `ps`/`footprint`
/// sampler on the host can read RSS at each phase. It does not assert; it is a
/// reproduction vehicle, not a product test.
final class MemoryReproUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = true
  }

  func testDriveHistoryAndTypingFlows() {
    let app = XCUIApplication()
    app.launch()
    dwell("LAUNCH_IDLE", seconds: 6)

    // --- Phase 1: History tab (auto PDF export on appear) ---
    let history = app.tabBars.buttons["History"]
    if history.waitForExistence(timeout: 10) {
      history.tap()
      dwell("HISTORY_APPEAR", seconds: 8)
      // Bounce back and forth — each appear re-fires .task(id:) export.
      let regimen = app.tabBars.buttons["Regimen"]
      for i in 0 ..< 5 {
        regimen.tap()
        history.tap()
        dwell("HISTORY_CYCLE_\(i)", seconds: 2)
      }
    } else {
      NSLog("MEMPROBE: History tab not found")
    }

    // --- Phase 2: Add-medication form typing storm ---
    app.tabBars.buttons["Regimen"].tap()
    dwell("REGIMEN_APPEAR", seconds: 2)
    let add = app.buttons["Add medication"]
    if add.waitForExistence(timeout: 5) {
      add.tap()
      let name = app.textFields["Name"]
      if name.waitForExistence(timeout: 5) {
        name.tap()
        // 60 keystrokes — each mutates formState.displayName → observation churn.
        for i in 0 ..< 60 {
          name.typeText("a")
          if i % 20 == 0 { dwell("TYPING_\(i)", seconds: 1) }
        }
        dwell("TYPING_DONE", seconds: 4)
      } else {
        NSLog("MEMPROBE: Name field not found")
      }
    } else {
      NSLog("MEMPROBE: Add medication button not found")
    }
    dwell("FINAL_IDLE", seconds: 4)
  }

  private func dwell(_ label: String, seconds: TimeInterval) {
    NSLog("MEMPROBE: phase=\(label) begin")
    Thread.sleep(forTimeInterval: seconds)
    NSLog("MEMPROBE: phase=\(label) end")
  }
}
