import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct WidgetTimelinePlanTests {
  private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
  }

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @discardableResult
  private func maintenanceMed(doses: [(Int, Int)], in context: ModelContext) -> Medication {
    let med = Medication(displayName: "Med", unitForm: .tablet, kind: .maintenance)
    context.insert(med)
    let schedule = doses.map { hour, minute in
      let dose = ScheduledDose(hour: hour, minute: minute, quantity: 1, medication: med)
      context.insert(dose)
      return dose
    }
    med.schedule = schedule
    return med
  }

  @Test func oneDoseYieldsOpenAndCloseEdges() throws {
    let context = try makeContext()
    let med = maintenanceMed(doses: [(8, 0)], in: context)
    let from = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00 UTC
    let dates = WidgetTimelinePlan.transitionDates(
      forMaintenance: [med],
      from: from,
      to: from.addingTimeInterval(24 * 3600),
      calendar: utcCalendar,
      windowMinutes: 60
    )
    // 08:00 ± 60 min → 07:00 and 09:00, both inside [00:00, 24:00].
    #expect(dates == [from.addingTimeInterval(7 * 3600), from.addingTimeInterval(9 * 3600)])
  }

  @Test func twoDosesSixHoursApartYieldFourEdges() throws {
    let context = try makeContext()
    let med = maintenanceMed(doses: [(8, 0), (14, 0)], in: context)
    let from = Date(timeIntervalSince1970: 0)
    let dates = WidgetTimelinePlan.transitionDates(
      forMaintenance: [med],
      from: from,
      to: from.addingTimeInterval(24 * 3600),
      calendar: utcCalendar,
      windowMinutes: 60
    )
    // 07:00, 09:00, 13:00, 15:00
    #expect(dates == [7, 9, 13, 15].map { from.addingTimeInterval(Double($0) * 3600) })
  }

  @Test func edgesOutsideRangeAreExcluded() throws {
    let context = try makeContext()
    let med = maintenanceMed(doses: [(8, 0)], in: context)
    // Window starts at 07:30 — the 07:00 opening edge is before `from` and dropped.
    let from = Date(timeIntervalSince1970: 7.5 * 3600)
    let dates = WidgetTimelinePlan.transitionDates(
      forMaintenance: [med],
      from: from,
      to: Date(timeIntervalSince1970: 24 * 3600),
      calendar: utcCalendar,
      windowMinutes: 60
    )
    #expect(dates == [Date(timeIntervalSince1970: 9 * 3600)]) // only the 09:00 closing edge
  }
}
