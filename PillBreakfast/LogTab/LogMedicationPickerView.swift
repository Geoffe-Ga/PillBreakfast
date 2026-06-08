import SwiftData
import SwiftUI

/// Searchable medication picker for the Log tab. Active regimen meds first,
/// archived second (`LogMedicationList`). Selecting a med pushes the confirm
/// step. Dismisses itself and reports the logged med's name back up on success.
struct LogMedicationPickerView: View {
  let onLogged: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Medication.displayName) private var medications: [Medication]
  @State private var query = ""

  private var sections: [LogMedicationList.Section] {
    LogMedicationList.sections(from: medications, query: query)
  }

  var body: some View {
    NavigationStack {
      Group {
        if medications.isEmpty {
          ContentUnavailableView(
            "No medications",
            systemImage: "pills",
            description: Text("Add a medication on the Regimen tab first.")
          )
        } else {
          List {
            ForEach(sections) { section in
              Section(section.title) {
                ForEach(section.medications) { medication in
                  NavigationLink {
                    LogDoseConfirmView(medication: medication) { name in
                      dismiss()
                      onLogged(name)
                    }
                  } label: {
                    row(medication)
                  }
                }
              }
            }
          }
          .listStyle(.insetGrouped)
          .scrollContentBackground(.hidden)
        }
      }
      .navigationTitle("Log a dose")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $query, prompt: "Search medications")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .glassBackground()
    }
  }

  private func row(_ medication: Medication) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
      LiquidGlassTheme.Typography.footnote(LogDoseDetail.summary(for: medication))
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
  }
}
