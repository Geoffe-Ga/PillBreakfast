import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct PendingDoseMealOrdinalTests {
  private func pendingDose(
    medication: UUID = UUID(),
    secondsFromMidnight: TimeInterval,
    mealID: UUID?,
    mealName: String?
  ) -> PendingDose {
    PendingDose(
      medicationID: medication,
      scheduledFor: Date(timeIntervalSince1970: secondsFromMidnight),
      quantity: 1,
      mealID: mealID,
      mealName: mealName
    )
  }

  @Test func ordinalIsAssignedToEachDoseInOrderWithinAMeal() {
    let mealID = UUID()
    let doses = [
      pendingDose(secondsFromMidnight: 0, mealID: mealID, mealName: "Pill Breakfast"),
      pendingDose(secondsFromMidnight: 1, mealID: mealID, mealName: "Pill Breakfast"),
      pendingDose(secondsFromMidnight: 2, mealID: mealID, mealName: "Pill Breakfast"),
    ]
    let assigned = PendingQueueSelector.assignMealOrdinals(to: doses)
    #expect(assigned.count == 3)
    #expect(assigned[0].mealOrdinal?.current == 1)
    #expect(assigned[0].mealOrdinal?.total == 3)
    #expect(assigned[1].mealOrdinal?.current == 2)
    #expect(assigned[2].mealOrdinal?.current == 3)
  }

  @Test func singletonMealLeavesOrdinalNilSoHeaderDropsTheOneOfOneSuffix() {
    let mealID = UUID()
    let doses = [pendingDose(secondsFromMidnight: 0, mealID: mealID, mealName: "Pill Dinner")]
    let assigned = PendingQueueSelector.assignMealOrdinals(to: doses)
    #expect(assigned.first?.mealOrdinal == nil)
    #expect(assigned.first?.mealName == "Pill Dinner")
  }

  @Test func ungroupedDosesGetNoOrdinalAndNoMealMetadata() {
    let doses = [
      pendingDose(secondsFromMidnight: 0, mealID: nil, mealName: nil),
      pendingDose(secondsFromMidnight: 1, mealID: nil, mealName: nil),
    ]
    let assigned = PendingQueueSelector.assignMealOrdinals(to: doses)
    #expect(assigned.allSatisfy { $0.mealOrdinal == nil && $0.mealName == nil })
  }

  @Test func twoDifferentMealsEachGetTheirOwnOrdinalSequence() {
    let breakfast = UUID()
    let dinner = UUID()
    let doses = [
      pendingDose(secondsFromMidnight: 0, mealID: breakfast, mealName: "Pill Breakfast"),
      pendingDose(secondsFromMidnight: 1, mealID: breakfast, mealName: "Pill Breakfast"),
      pendingDose(secondsFromMidnight: 100, mealID: dinner, mealName: "Pill Dinner"),
      pendingDose(secondsFromMidnight: 101, mealID: dinner, mealName: "Pill Dinner"),
    ]
    let assigned = PendingQueueSelector.assignMealOrdinals(to: doses)
    #expect(assigned[0].mealOrdinal == PendingDose.MealOrdinal(current: 1, total: 2))
    #expect(assigned[1].mealOrdinal == PendingDose.MealOrdinal(current: 2, total: 2))
    #expect(assigned[2].mealOrdinal == PendingDose.MealOrdinal(current: 1, total: 2))
    #expect(assigned[3].mealOrdinal == PendingDose.MealOrdinal(current: 2, total: 2))
  }
}
