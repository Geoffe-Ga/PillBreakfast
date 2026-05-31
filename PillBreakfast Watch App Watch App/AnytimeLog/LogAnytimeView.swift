import SwiftData
import SwiftUI

/// Watch "Log a scheduled dose anytime" list. Picks a maintenance med, navigates
/// to `LogAnytimeConfirmView` which writes a `DoseEvent` with `scheduledFor: nil`.
struct LogAnytimeView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]

  /// PRN gets its own list with the quantity picker; this surface is for the
  /// scheduled (maintenance) doses that the queue won't auto-surface.
  private var maintenanceMedications: [Medication] {
    medications.filter { $0.kind == .maintenance }
  }

  var body: some View {
    Group {
      if maintenanceMedications.isEmpty {
        VStack(spacing: LiquidGlassTheme.Spacing.compact) {
          Image(systemName: "calendar.badge.clock")
            .font(.title2)
          LiquidGlassTheme.Typography.title("No scheduled meds")
        }
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(maintenanceMedications) { medication in
          NavigationLink {
            LogAnytimeConfirmView(medication: medication, onLogged: { dismiss() })
          } label: {
            row(for: medication)
          }
        }
      }
    }
    .navigationTitle("Log anytime")
    .glassBackground()
  }

  private func row(for medication: Medication) -> some View {
    let quantity = AnytimeLogQuantity.defaultQuantity(for: medication)
    let unit = quantity == 1 ? medication.unitForm.singularLabel : medication.unitForm.pluralLabel
    return VStack(alignment: .leading, spacing: 2) {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
      LiquidGlassTheme.Typography.footnote("\(quantity) \(unit)")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
  }
}

#Preview {
  NavigationStack {
    LogAnytimeView()
  }
  .modelContainer(for: Medication.self, inMemory: true)
}
