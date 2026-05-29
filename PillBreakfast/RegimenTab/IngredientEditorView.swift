import os
import SwiftData
import SwiftUI

/// Edits one ingredient's safety thresholds and high-risk flag. This is where the
/// user takes responsibility for the numbers the safety system enforces — the
/// disclaimer is shown here too. On save, the regimen snapshot is re-pushed so the
/// watch picks up the change.
struct IngredientEditorView: View {
  let ingredient: Ingredient

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var ceilingText: String
  @State private var intervalText: String
  @State private var isHighRisk: Bool
  @State private var saveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  init(ingredient: Ingredient) {
    self.ingredient = ingredient
    _ceilingText = State(initialValue: ingredient.dailyCeilingMg.map { String(Int($0.rounded())) } ?? "")
    _intervalText = State(initialValue: ingredient.minIntervalMinutes.map(String.init) ?? "")
    _isHighRisk = State(initialValue: ingredient.isHighRisk)
  }

  var body: some View {
    Form {
      if !ingredient.aliases.isEmpty {
        Section("Aliases") {
          Text(ingredient.aliases.joined(separator: ", "))
            .foregroundStyle(.secondary)
        }
      }

      Section {
        TextField("e.g. 4000", text: $ceilingText)
          .keyboardType(.numberPad)
      } header: {
        Text("Daily ceiling (mg)")
      } footer: {
        Text("Leave blank for no ceiling.")
      }

      Section {
        TextField("e.g. 240", text: $intervalText)
          .keyboardType(.numberPad)
      } header: {
        Text("Minimum interval (minutes)")
      } footer: {
        Text("Leave blank for no spacing rule.")
      }

      Section {
        Toggle("High risk", isOn: $isHighRisk)
      } footer: {
        Text("Toggling this on requires press-and-hold to confirm every product containing this ingredient.")
      }

      Section {
        Text(IngredientLibrarySeeder.disclaimer)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle(ingredient.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: save)
          // Don't let a non-numeric entry save silently as "no change" — block it.
          .disabled(!isValid)
      }
    }
    .alert(
      "Couldn't save",
      isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("OK", role: .cancel) { saveError = nil }
    } message: {
      Text(saveError ?? "")
    }
  }

  /// A field is valid when it's blank (means "no threshold") or parses cleanly.
  /// Save is blocked otherwise so a typo can't masquerade as "no change".
  private var isValid: Bool {
    let ceiling = ceilingText.trimmingCharacters(in: .whitespaces)
    let interval = intervalText.trimmingCharacters(in: .whitespaces)
    let ceilingOK = ceiling.isEmpty || Double(ceiling) != nil
    let intervalOK = interval.isEmpty || Int(interval) != nil
    return ceilingOK && intervalOK
  }

  private func save() {
    // Empty → no threshold. Non-numeric input is ignored (field keeps the old value).
    let trimmedCeiling = ceilingText.trimmingCharacters(in: .whitespaces)
    let trimmedInterval = intervalText.trimmingCharacters(in: .whitespaces)
    ingredient.dailyCeilingMg = trimmedCeiling.isEmpty ? nil : Double(trimmedCeiling) ?? ingredient.dailyCeilingMg
    ingredient.minIntervalMinutes = trimmedInterval.isEmpty ? nil : Int(trimmedInterval) ?? ingredient.minIntervalMinutes
    ingredient.isHighRisk = isHighRisk

    do {
      try modelContext.save()
    } catch {
      IngredientEditorView.logger.error("Failed to save ingredient edit: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    dismiss()
  }
}
