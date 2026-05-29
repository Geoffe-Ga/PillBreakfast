import os
import SwiftData
import SwiftUI

/// Per-medication ingredient confirmation step of the Apple Health import flow
/// (SPEC §6.1 — composition must be user-confirmed because Health doesn't
/// expose it). Each imported draft is shown with a multi-select picker over the
/// seeded ingredient library plus an inline "Add new" affordance. Import inserts
/// one `Medication` per draft with `healthKitConceptID` and the selected
/// ingredients as `MedicationComponent`s, then pushes the snapshot to the watch.
struct ConfirmComponentsView: View {
  let drafts: [MedicationDraft]
  /// Called after a successful save so the presenter (the import sheet) can
  /// dismiss itself. The view dismisses its own NavigationStack entry on cancel.
  let onComplete: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Ingredient.name) private var library: [Ingredient]

  /// draft.id → ingredient IDs the user has selected for that draft.
  @State private var selections: [UUID: Set<UUID>] = [:]
  /// draft.id → in-progress new-ingredient name. Reset after each add.
  @State private var newNames: [UUID: String] = [:]
  /// UUIDs of ingredients created inline in this session, for cancel cleanup.
  @State private var createdIngredientIDs: [UUID] = []

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HealthImport"
  )

  /// Health doesn't expose per-unit milligrams, so newly imported components
  /// start at 0 mg and the user edits the dose in the regimen UI.
  private static let defaultDosagePerUnitMg: Double = 0

  var body: some View {
    List {
      ForEach(drafts) { draft in
        Section(draft.displayName) {
          ForEach(library) { ingredient in
            row(draft: draft, ingredient: ingredient)
          }
          addNewRow(for: draft)
        }
      }
    }
    .navigationTitle("Confirm Components")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { cancel() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Import") { performImport() }
      }
    }
    .onAppear(perform: applyAutoSuggestions)
  }

  private func row(draft: MedicationDraft, ingredient: Ingredient) -> some View {
    let isSelected = selections[draft.id, default: []].contains(ingredient.id)
    return Button {
      toggle(ingredient: ingredient.id, for: draft.id)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(ingredient.name)
          if !ingredient.aliases.isEmpty {
            Text(ingredient.aliases.joined(separator: ", "))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? .primary : .secondary)
          .accessibilityLabel(isSelected ? "Selected" : "Not selected")
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private func addNewRow(for draft: MedicationDraft) -> some View {
    HStack {
      TextField(
        "Add ingredient",
        text: Binding(
          get: { newNames[draft.id, default: ""] },
          set: { newNames[draft.id] = $0 }
        )
      )
      .textInputAutocapitalization(.words)
      Button("Add") { addNew(for: draft) }
        .disabled(trimmedNewName(for: draft).isEmpty)
    }
  }

  private func toggle(ingredient id: UUID, for draftID: UUID) {
    var set = selections[draftID, default: []]
    if set.contains(id) {
      set.remove(id)
    } else {
      set.insert(id)
    }
    selections[draftID] = set
  }

  private func trimmedNewName(for draft: MedicationDraft) -> String {
    newNames[draft.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addNew(for draft: MedicationDraft) {
    let name = trimmedNewName(for: draft)
    guard !name.isEmpty else { return }
    let ingredient = Ingredient(name: name)
    modelContext.insert(ingredient)
    createdIngredientIDs.append(ingredient.id)
    selections[draft.id, default: []].insert(ingredient.id)
    newNames[draft.id] = ""
  }

  private func applyAutoSuggestions() {
    for draft in drafts {
      if selections[draft.id] == nil,
         let suggested = HealthMedicationMapper.suggestedIngredient(for: draft, in: library)
      {
        selections[draft.id] = [suggested.id]
      }
    }
  }

  private func cancel() {
    InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
    dismiss()
  }

  private func performImport() {
    for draft in drafts {
      let medication = Medication(
        displayName: draft.displayName,
        unitForm: .tablet,
        kind: .maintenance,
        healthKitConceptID: draft.healthKitConceptID
      )
      modelContext.insert(medication)
      let selectedIDs = selections[draft.id, default: []]
      for ingredient in library where selectedIDs.contains(ingredient.id) {
        modelContext.insert(
          MedicationComponent(
            medication: medication,
            ingredient: ingredient,
            dosagePerUnitMg: Self.defaultDosagePerUnitMg
          )
        )
      }
    }
    do {
      try modelContext.save()
    } catch {
      Self.logger.error("Health import save failed: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    onComplete()
    dismiss()
  }
}
