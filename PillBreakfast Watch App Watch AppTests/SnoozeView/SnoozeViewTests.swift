import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import Testing

@MainActor
struct SnoozeViewTests {
  private func calendar() throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    return calendar
  }

  private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, in calendar: Calendar) throws -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return try #require(calendar.date(from: c))
  }

  @Test func targetLabelSaysTodayWhenTimeIsAhead() throws {
    let cal = try calendar()
    let now = try date(2026, 5, 15, 10, 0, in: cal)
    let picked = try date(2026, 5, 15, 14, 30, in: cal)
    #expect(SnoozeView.targetLabel(for: picked, now: now, calendar: cal).contains("today"))
  }

  @Test func targetLabelSaysTomorrowWhenTimeHasPassed() throws {
    let cal = try calendar()
    let now = try date(2026, 5, 15, 23, 50, in: cal)
    let picked = try date(2026, 5, 15, 6, 30, in: cal) // earlier than now → rolls over
    #expect(SnoozeView.targetLabel(for: picked, now: now, calendar: cal).contains("tomorrow"))
  }

  @Test func constructs() {
    _ = SnoozeView(context: SnoozeContext(scheduledDoseID: UUID(), originalScheduledFor: .now, medicationName: "Vitamin D"))
  }
}
