import SwiftData
import SwiftUI

/// iPhone root: Regimen (setup), Log (manual dose entry), History, and Settings.
/// The watch remains the primary logging surface and the only one that *prompts*
/// ("take pills now"); the Log tab is a pull-based, user-initiated convenience
/// that writes through the same `DoseEventWriter` path and syncs to the watch
/// (SPEC §6.4).
struct MainTabView: View {
  var body: some View {
    TabView {
      RegimenTabHostView()
        .tabItem { Label("Regimen", systemImage: "pills") }

      LogTabHostView()
        .tabItem { Label("Log", systemImage: "plus.circle.fill") }

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
