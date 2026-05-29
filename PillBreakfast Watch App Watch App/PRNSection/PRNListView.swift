import os
import SwiftData
import SwiftUI

/// Watch "Take as-needed" screen: lists the PRN products with their real
/// running-total summary (SPEC §7.3), tapping through to the quantity picker.
/// Reached from the root, never from the maintenance tap-through queue (SPEC §2.3).
struct PRNListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var summaries: [UUID: PRNRowSummary] = [:]

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "PRNList")

  private var prnMedications: [Medication] {
    medications.filter { $0.kind == .prn }
  }

  /// Re-key the reload when the set of PRN products or their composition changes.
  private var signature: Int {
    var hasher = Hasher()
    for med in prnMedications {
      hasher.combine(med.id)
      for component in med.components {
        hasher.combine(component.id)
      }
    }
    return hasher.finalize()
  }

  var body: some View {
    Group {
      if prnMedications.isEmpty {
        VStack(spacing: LiquidGlassTheme.Spacing.compact) {
          Image(systemName: "pills")
            .font(.title2)
          LiquidGlassTheme.Typography.title("No as-needed meds")
        }
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(prnMedications) { medication in
          NavigationLink {
            PRNQuantityPickerView(medication: medication, onLogged: reload)
          } label: {
            PRNRowView(summary: summaries[medication.id] ?? placeholder(for: medication))
          }
        }
      }
    }
    .navigationTitle("As-Needed")
    .glassBackground()
    .task(id: signature) { reload() }
  }

  /// Shown until the real summary loads (or if building one fails) — just the name.
  private func placeholder(for medication: Medication) -> PRNRowSummary {
    PRNRowSummary(
      medicationID: medication.id,
      displayName: medication.displayName,
      firstLine: medication.displayName,
      secondLine: "…",
      highlightedIngredientID: nil
    )
  }

  private func reload() {
    var built: [UUID: PRNRowSummary] = [:]
    for medication in prnMedications {
      do {
        built[medication.id] = try PRNRowSummaryBuilder.summary(for: medication, at: .now, in: modelContext)
      } catch {
        PRNListView.logger.error("Failed to build PRN summary for \(medication.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
      }
    }
    summaries = built
  }
}

#Preview {
  NavigationStack {
    PRNListView()
  }
  .modelContainer(for: Medication.self, inMemory: true)
}
