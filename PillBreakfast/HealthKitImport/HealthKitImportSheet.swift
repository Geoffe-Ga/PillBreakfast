import SwiftUI

/// Stub "Import from Apple Health" sheet (SPEC §6.1); real flow lands in EPIC 07.
struct HealthKitImportSheet: View {
  @Environment(\.dismiss) private var dismiss

  // @State (not let) so the actor survives SwiftUI redraws once ISSUE_02 adds real state.
  @State private var service = HealthKitImportService()
  @State private var message = "Checking Apple Health…"

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Image(systemName: "heart.text.square")
          .font(.largeTitle)
          .foregroundStyle(.secondary)
        Text("Import from Apple Health")
          .font(.headline)
        Text(message)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
      .navigationTitle("Apple Health")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .task {
        switch await service.importMedications() {
        case .comingSoon:
          message = "Import flow coming next issue. PillBreakfast only reads from Apple Health — it never writes."
        }
      }
    }
  }
}

#Preview {
  HealthKitImportSheet()
}
