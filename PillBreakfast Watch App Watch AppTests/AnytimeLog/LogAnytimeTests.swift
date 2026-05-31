import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import SwiftData
import Testing

@MainActor
struct LogAnytimeTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func defaultQuantityFollowsEarliestScheduledDose() throws {
    let context = try makeContext()
    let med = Medication(displayName: "Metoprolol", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 2),
      ScheduledDose(hour: 20, minute: 0, quantity: 1),
    ]
    context.insert(med)
    try context.save()

    #expect(AnytimeLogQuantity.defaultQuantity(for: med) == 2)
  }

  @Test func defaultQuantityIsInsertionOrderIndependent() throws {
    // Reversed insertion order — the 20:00 dose lands first in the array.
    // Earliest-by-time still picks the 8:00 dose's quantity.
    let context = try makeContext()
    let med = Medication(displayName: "Metoprolol", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 20, minute: 0, quantity: 1),
      ScheduledDose(hour: 8, minute: 0, quantity: 2),
    ]
    context.insert(med)
    try context.save()

    #expect(AnytimeLogQuantity.defaultQuantity(for: med) == 2)
  }

  @Test func medicationUnitFormDrivesUserFacingLabels() {
    #expect(MedicationForm.tablet.singularLabel == "tablet")
    #expect(MedicationForm.tablet.pluralLabel == "tablets")
    #expect(MedicationForm.capsule.singularLabel == "capsule")
    #expect(MedicationForm.capsule.pluralLabel == "capsules")
    #expect(MedicationForm.liquid.singularLabel == "mL")
    #expect(MedicationForm.other.singularLabel == "dose")
    #expect(MedicationForm.other.pluralLabel == "doses")
  }

  @Test func defaultQuantityFallsBackToOneWhenScheduleIsEmpty() throws {
    let context = try makeContext()
    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    context.insert(med)
    try context.save()

    #expect(AnytimeLogQuantity.defaultQuantity(for: med) == 1)
  }

  @Test func anytimeLogWritesEventWithNilScheduledForAndWatchSource() throws {
    let context = try makeContext()
    let ingredient = Ingredient(name: "Cholecalciferol")
    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    med.components = [MedicationComponent(ingredient: ingredient, dosagePerUnitMg: 50)]
    med.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1)]
    context.insert(med)
    try context.save()

    let event = try DoseEventWriter.writeDoseEvent(
      for: med,
      scheduledFor: nil,
      quantity: AnytimeLogQuantity.defaultQuantity(for: med),
      status: .taken,
      loggedOn: .watch,
      at: .now,
      in: context
    )

    #expect(event.scheduledFor == nil)
    #expect(event.loggedOn == .watch)
    #expect(event.status == .taken)
    #expect(event.quantity == 1)
    // The ingredient snapshot is built at log time and carries the per-dose mg.
    #expect(event.ingredientAmounts.count == 1)
    #expect(event.ingredientAmounts.first?.totalMg == 50)
  }

  @Test func pendingQueueSelectorIgnoresAnytimeProactiveLogs() throws {
    // Regression pin: a proactive (scheduledFor == nil) dose for a maintenance
    // med must not satisfy the "already logged" guard inside the ± 60 min
    // window — the slot still needs to fire its scheduled prompt. The
    // selector keys on (medicationID, hour, minute) drawn from `scheduledFor`,
    // so an event with nil `scheduledFor` should be invisible to the slot
    // dedup.
    let context = try makeContext()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))

    let med = Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance)
    med.schedule = [ScheduledDose(hour: 9, minute: 30, quantity: 1)]
    context.insert(med)
    try context.save()

    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 31
    components.hour = 9
    components.minute = 30
    let scheduledMoment = try #require(calendar.date(from: components))

    // Log a proactive (anytime) dose at 7:00 AM — two hours before the slot.
    var proactiveComponents = components
    proactiveComponents.hour = 7
    proactiveComponents.minute = 0
    let proactiveMoment = try #require(calendar.date(from: proactiveComponents))
    _ = try DoseEventWriter.writeDoseEvent(
      for: med,
      scheduledFor: nil,
      quantity: 1,
      status: .taken,
      loggedOn: .watch,
      at: proactiveMoment,
      in: context
    )

    // The 9:30 slot is still due at 9:30 — the proactive log doesn't dedup it.
    // (Geoff covers his own double-dose risk by not also tapping the queue
    // prompt; the model layer's contract here is just "don't lie about the
    // slot's dedup state.")
    let pending = try PendingQueueSelector(calendar: calendar)
      .pendingDoses(at: scheduledMoment, in: context)
    #expect(pending.count == 1)
    #expect(pending.first?.medicationID == med.id)
  }
}
