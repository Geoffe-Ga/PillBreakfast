import SwiftData
import SwiftUI

/// Read-only grouped list of the regimen, split into Maintenance and PRN
/// sections. Add/edit/archive affordances land in EPIC_03_ISSUE_02.
struct RegimenListView: View {
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]

  private var maintenance: [Medication] {
    medications.filter { $0.kind == .maintenance }
  }

  private var prn: [Medication] {
    medications.filter { $0.kind == .prn }
  }

  var body: some View {
    List {
      if medications.isEmpty {
        ContentUnavailableView("No medications yet", systemImage: "pills")
      } else {
        section("Maintenance", medications: maintenance)
        section("PRN", medications: prn)
      }
    }
  }

  @ViewBuilder
  private func section(_ title: String, medications: [Medication]) -> some View {
    if !medications.isEmpty {
      Section(title) {
        ForEach(medications) { medication in
          Text(medication.displayName)
        }
      }
    }
  }
}

#Preview {
  RegimenListView()
    .modelContainer(for: Medication.self, inMemory: true)
}
