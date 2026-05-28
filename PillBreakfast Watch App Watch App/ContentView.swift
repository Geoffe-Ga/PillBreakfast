import SwiftData
import SwiftUI

struct RootView: View {
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]

  var body: some View {
    NavigationStack {
      List {
        if medications.isEmpty {
          Text("Waiting for regimen…")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          // Read-only: the watch never edits the regimen (SPEC §6).
          ForEach(medications) { medication in
            Text(medication.displayName)
          }
        }
      }
      .navigationTitle("Pills")
    }
  }
}

#Preview {
  RootView()
    .modelContainer(for: Medication.self, inMemory: true)
}
