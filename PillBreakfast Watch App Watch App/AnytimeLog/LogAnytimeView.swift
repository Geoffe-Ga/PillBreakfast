import os
import SwiftData
import SwiftUI

/// Watch "Log a scheduled dose anytime" screen: lists every maintenance med so
/// the user can log a dose outside `PendingQueueSelector`'s ± 60-min window
/// (e.g. taking 9:30 AM at 7:00 AM before leaving the house, or 11:30 AM after
/// the window closed). Writes a `DoseEvent` with `scheduledFor: nil` — these
/// are proactive logs not tied to a slot.
struct LogAnytimeView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var writeFailed = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "AnytimeLog")

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
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Something went wrong saving this dose. Please try again.")
    }
  }

  private func row(for medication: Medication) -> some View {
    let quantity = AnytimeLogQuantity.defaultQuantity(for: medication)
    let unit = quantity == 1 ? "tablet" : "tablets"
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
