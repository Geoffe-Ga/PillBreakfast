import Foundation
@testable import PillBreakfast
import Testing

@MainActor
struct RegimenListViewTests {
  // MARK: - scheduleSummary

  @Test func scheduleSummaryReportsAsNeededForPRN() {
    let prn = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    #expect(RegimenListView.scheduleSummary(for: prn) == "As-needed")
  }

  @Test func scheduleSummaryReportsNoDosesForMaintenanceWithEmptySchedule() {
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    // Default schedule is empty.
    #expect(RegimenListView.scheduleSummary(for: med) == "No doses scheduled")
  }

  @Test func scheduleSummaryUsesSingularForOneDailyDose() {
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1, daysOfWeek: []),
    ]
    #expect(RegimenListView.scheduleSummary(for: med) == "1 daily dose")
  }

  @Test func scheduleSummaryUsesPluralForTwoDailyDoses() {
    // Pin the singular/plural boundary at count == 2 explicitly — the
    // existing 3-dose test covers the same branch but a one-step-off
    // regression at 2 would otherwise slip through.
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1, daysOfWeek: []),
      ScheduledDose(hour: 20, minute: 0, quantity: 1, daysOfWeek: []),
    ]
    #expect(RegimenListView.scheduleSummary(for: med) == "2 daily doses")
  }

  @Test func scheduleSummaryUsesPluralForMultipleDailyDoses() {
    let med = Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance)
    med.schedule = [
      ScheduledDose(hour: 8, minute: 0, quantity: 1, daysOfWeek: []),
      ScheduledDose(hour: 14, minute: 0, quantity: 1, daysOfWeek: []),
      ScheduledDose(hour: 20, minute: 0, quantity: 1, daysOfWeek: []),
    ]
    #expect(RegimenListView.scheduleSummary(for: med) == "3 daily doses")
  }
}
