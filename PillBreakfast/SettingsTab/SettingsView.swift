import SwiftData
import SwiftUI

/// iPhone Settings. First real entry: the high-risk press-and-hold duration,
/// which syncs to the watch on the next regimen push (SPEC §6.3).
struct SettingsView: View {
  @Environment(UserPreferencesStore.self) private var store
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    @Bindable var store = store
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Hold duration")
              Spacer()
              Text(durationLabel(store.preferences.highRiskHoldDurationSeconds))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Slider(
              value: $store.preferences.highRiskHoldDurationSeconds,
              in: UserPreferences.holdDurationRange,
              step: 0.1
            ) { editing in
              // Push once the user finishes dragging, not on every continuous tick.
              if !editing { pushPreferences() }
            }
          }
        } header: {
          Text("High-risk confirmation")
        } footer: {
          Text("How long to press and hold before a high-risk dose is logged on the watch.")
        }

        Section {
          Button("Reset to defaults") {
            store.reset()
            pushPreferences()
          }
        }
      }
      .navigationTitle("Settings")
    }
  }

  private func durationLabel(_ seconds: TimeInterval) -> String {
    String(format: "%.1fs", seconds)
  }

  /// Preferences ride on the regimen snapshot, so a push carries the new value to
  /// the watch ("latest wins"; persists if the watch is offline).
  private func pushPreferences() {
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
  }
}

#Preview {
  SettingsView()
    .environment(UserPreferencesStore())
    .modelContainer(for: Medication.self, inMemory: true)
}
