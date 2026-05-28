import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import SwiftData
import Testing

/// Watch-target smoke coverage for the shared selector — the exhaustive edge-case
/// suite lives in the iOS test target (`PillBreakfastTests/Queue`). These two
/// confirm the selector links and behaves on the watchOS build.
@MainActor
struct PendingQueueSelectorTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func easternCalendar() throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    return calendar
  }

  private func date(_ hour: Int, _ minute: Int, in calendar: Calendar) throws -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 29
    components.hour = hour
    components.minute = minute
    return try #require(calendar.date(from: components))
  }

  @Test func returnsDoseWithinWindow() throws {
    let cal = try easternCalendar()
    let context = try makeContext()
    let med = Medication(displayName: "Lithium 300mg", unitForm: .tablet, kind: .maintenance)
    med.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(med)
    try context.save()

    let result = try PendingQueueSelector(calendar: cal).pendingDoses(at: date(8, 5, in: cal), in: context)
    #expect(result.count == 1)
    #expect(try #require(result.first).medicationID == med.id)
  }

  @Test func suppressesDoseAlreadyTakenToday() throws {
    let cal = try easternCalendar()
    let context = try makeContext()
    let med = Medication(displayName: "Lithium 300mg", unitForm: .tablet, kind: .maintenance)
    med.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(med)
    let scheduledFor = try date(8, 0, in: cal)
    context.insert(DoseEvent(
      medication: med,
      scheduledFor: scheduledFor,
      takenAt: scheduledFor,
      quantity: 1,
      status: .taken,
      loggedOn: .watch
    ))
    try context.save()

    #expect(try PendingQueueSelector(calendar: cal).pendingDoses(at: date(8, 5, in: cal), in: context).isEmpty)
  }
}
