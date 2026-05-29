import SwiftUI

/// Stub "Import from Apple Health" sheet (SPEC §6.1). Opens from the Regimen tab,
/// explains that import isn't wired yet, and dismisses. The real authorization +
/// query + mapping flow replaces the body across later EPIC 07 issues; the sheet
/// already routes through `HealthKitImportService` so that wiring stays in place.
struct HealthKitImportSheet: View {
  @Environment(\.dismiss) private var dismiss

  // @State (not let) so SwiftUI owns the actor's lifetime across redraws — once
  // ISSUE_02 adds real state (authorization status), a plain let would reset it on
  // every re-render.
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
