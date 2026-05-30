import SwiftData
import SwiftUI

/// iPhone root: Regimen (real, read-only for now), plus History and Settings stubs.
/// The iPhone is setup + review only — there is no dose-logging UI anywhere here.
struct MainTabView: View {
  var body: some View {
    TabView {
      RegimenTabHostView()
        .tabItem { Label("Regimen", systemImage: "pills") }

      HistoryTabView()
        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
  }
}

#Preview {
  MainTabView()
    .environment(UserPreferencesStore())
    .modelContainer(for: [Medication.self, DoseEvent.self], inMemory: true)
}
