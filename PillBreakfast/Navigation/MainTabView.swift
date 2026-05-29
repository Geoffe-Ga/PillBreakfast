import SwiftData
import SwiftUI

/// iPhone root: Regimen (real, read-only for now), plus History and Settings stubs.
/// The iPhone is setup + review only — there is no dose-logging UI anywhere here.
struct MainTabView: View {
  var body: some View {
    TabView {
      RegimenTabHostView()
        .tabItem { Label("Regimen", systemImage: "pills") }

      ComingSoonView(title: "History")
        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
  }
}

private struct ComingSoonView: View {
  let title: String

  var body: some View {
    NavigationStack {
      Text("Coming soon")
        .foregroundStyle(.secondary)
        .navigationTitle(title)
    }
  }
}

#Preview {
  MainTabView()
    .environment(UserPreferencesStore())
    .modelContainer(for: Medication.self, inMemory: true)
}
