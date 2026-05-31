import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct MealHeaderTests {
  private func pendingDose(
    mealName: String?,
    ordinal: PendingDose.MealOrdinal? = nil
  ) -> PendingDose {
    PendingDose(
      medicationID: UUID(),
      scheduledFor: .now,
      quantity: 1,
      mealID: mealName == nil ? nil : UUID(),
      mealName: mealName,
      mealOrdinal: ordinal
    )
  }

  @Test func ordinalRendersAsTwoOfFive() {
    let dose = pendingDose(mealName: "Pill Breakfast", ordinal: PendingDose.MealOrdinal(current: 2, total: 5))
    #expect(TapThroughQueueView.mealHeader(for: dose) == "Pill Breakfast · 2 of 5")
  }

  @Test func singletonMealRendersWithoutOrdinal() {
    let dose = pendingDose(mealName: "Pill Dinner", ordinal: nil)
    #expect(TapThroughQueueView.mealHeader(for: dose) == "Pill Dinner")
  }

  @Test func ungroupedDoseProducesNoHeader() {
    let dose = pendingDose(mealName: nil, ordinal: nil)
    #expect(TapThroughQueueView.mealHeader(for: dose) == nil)
  }
}
