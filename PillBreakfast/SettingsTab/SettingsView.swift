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
          VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
            HStack {
              Text("Hold duration")
              Spacer()
              // Scaling to 0.8 keeps the dosage figure on one line at AX5 next to the slider.
              LiquidGlassTheme.Typography.dosage(durationLabel(store.preferences.highRiskHoldDurationSeconds))
                .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
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
          LiquidGlassTheme.Typography.headline("High-risk confirmation")
            .textCase(nil)
        } footer: {
          LiquidGlassTheme.Typography.footnote("How long to press and hold before a high-risk dose is logged on the watch.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }

        Section {
          Picker("Default snooze", selection: $store.preferences.defaultSnoozeOffsetMinutes) {
            ForEach(UserPreferences.allowedSnoozeOffsets, id: \.self) { minutes in
              Text("\(minutes) min").tag(minutes)
            }
          }
          .onChange(of: store.preferences.defaultSnoozeOffsetMinutes) { _, _ in
            pushPreferences()
          }
        } footer: {
          LiquidGlassTheme.Typography.footnote("Starting position for the snooze picker on the watch.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }

        Section {
          Button("Reset to defaults") {
            store.reset()
            pushPreferences()
          }
        }

        Section {
          NavigationLink {
            IngredientsListView()
          } label: {
            Label("Ingredients", systemImage: "list.bullet.rectangle")
          }
        } footer: {
          LiquidGlassTheme.Typography.footnote("Edit ingredient ceilings, spacing, and high-risk flags.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      }
      .scrollContentBackground(.hidden)
      .glassBackground()
      .navigationTitle("Settings")
      .toolbarTitleDisplayMode(.large)
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
