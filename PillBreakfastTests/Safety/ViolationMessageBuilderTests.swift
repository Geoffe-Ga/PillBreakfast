import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct ViolationMessageBuilderTests {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  @Test func ceilingMessageNamesIngredientAndTotals() {
    let apap = Ingredient(name: "Acetaminophen")
    let violation = Violation.ceiling(ingredient: apap, current: 1500, proposed: 4500, ceiling: 4000)

    let message = ViolationMessageBuilder.message(for: violation, at: now)
    #expect(message.title == "Acetaminophen")
    #expect(message.id == "ceiling:\(apap.id)")
    #expect(message.detailLines == [
      "Already today: 1500 mg",
      "Would total: 4500 mg",
      "Daily limit: 4000 mg",
    ])
  }

  @Test func ceilingMessageRoundsMilligrams() {
    let apap = Ingredient(name: "Acetaminophen")
    let violation = Violation.ceiling(ingredient: apap, current: 325.5, proposed: 650.4, ceiling: 4000)

    let message = ViolationMessageBuilder.message(for: violation, at: now)
    #expect(message.detailLines.first == "Already today: 326 mg") // 325.5 rounds up
    #expect(message.detailLines[1] == "Would total: 650 mg") // 650.4 rounds down
  }

  @Test func tooSoonMessageShowsSpacingAndElapsed() throws {
    let apap = Ingredient(name: "Acetaminophen")
    let lastTaken = now.addingTimeInterval(-80 * 60) // 1h 20m ago
    let violation = Violation.tooSoon(ingredient: apap, lastTakenAt: lastTaken, minInterval: 240)

    let message = ViolationMessageBuilder.message(for: violation, at: now)
    #expect(message.title == "Acetaminophen")
    #expect(message.id == "tooSoon:\(apap.id)")
    #expect(message.detailLines.contains("Recommended spacing: 4h"))
    #expect(try #require(message.detailLines.first).contains("(1h 20m ago)"))
  }
}
