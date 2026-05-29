import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct ScheduledDoseIDParsingTests {
  @Test func parsesDoseIDFromDailyIdentifier() {
    let doseID = UUID()
    let identifier = "\(NotificationScheduler.identifierPrefix)\(doseID.uuidString)"
    #expect(NotificationScheduler.scheduledDoseID(fromIdentifier: identifier) == doseID)
  }

  @Test func parsesDoseIDFromWeekdaySuffixedIdentifier() {
    let doseID = UUID()
    let identifier = "\(NotificationScheduler.identifierPrefix)\(doseID.uuidString).3"
    #expect(NotificationScheduler.scheduledDoseID(fromIdentifier: identifier) == doseID)
  }

  @Test func returnsNilForForeignIdentifier() {
    #expect(NotificationScheduler.scheduledDoseID(fromIdentifier: "com.someone.else.thing.123") == nil)
    #expect(NotificationScheduler.scheduledDoseID(fromIdentifier: "\(NotificationScheduler.identifierPrefix)not-a-uuid") == nil)
  }
}
