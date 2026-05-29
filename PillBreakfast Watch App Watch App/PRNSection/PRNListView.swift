import SwiftData
import SwiftUI

/// Watch "Take as-needed" screen: lists the PRN products with their running-total
/// summary. Reached from the root, never from the maintenance tap-through queue
/// (SPEC §2.3). Totals are stubbed to zero until EPIC_05_ISSUE_02; the quantity
/// picker and ceiling checks land in later EPIC 05 issues.
struct PRNListView: View {
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]

  private var summaries: [PRNRowSummary] {
    medications.filter { $0.kind == .prn }.map(PRNStubTotals.summary(for:))
  }

  var body: some View {
    Group {
      if summaries.isEmpty {
        VStack(spacing: LiquidGlassTheme.Spacing.compact) {
          Image(systemName: "pills")
            .font(.title2)
          LiquidGlassTheme.Typography.title("No as-needed meds")
        }
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(summaries) { summary in
          VStack(alignment: .leading, spacing: 2) {
            LiquidGlassTheme.Typography.medicationName(summary.displayName)
            LiquidGlassTheme.Typography.caption(summary.summaryText)
              .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          }
        }
      }
    }
    .navigationTitle("As-Needed")
    .glassBackground()
  }
}

#Preview {
  NavigationStack {
    PRNListView()
  }
  .modelContainer(for: Medication.self, inMemory: true)
}
