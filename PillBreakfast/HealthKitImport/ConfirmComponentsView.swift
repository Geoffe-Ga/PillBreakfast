import os
import SwiftData
import SwiftUI

/// NavigationStack route from the import sheet's selection list to the
/// per-medication ingredient confirmation step. Defined here (next to the
/// destination view) so the navigation contract is collocated with its target.
///
/// `nonisolated` + explicit `Sendable` for the same reason as `MedicationDraft`
/// (see that type's note).
nonisolated struct ConfirmComponentsRoute: Hashable {
  let drafts: [MedicationDraft]
}

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
  /// Existing Pill Meals — drives the post-import "Add to Pill Meals?" step
  /// (§8.4). When empty, the step is skipped (nothing to assign to).
  @Query(sort: [SortDescriptor(\PillMeal.sortOrder), SortDescriptor(\PillMeal.createdAt)])
  private var pillMeals: [PillMeal]

  /// draft.id → ingredient IDs the user has selected for that draft.
  @State private var selections: [UUID: Set<UUID>] = [:]
  /// draft.id → in-progress new-ingredient name. Reset after each add.
  @State private var newNames: [UUID: String] = [:]
  /// UUIDs of ingredients created inline in this session, for cancel cleanup.
  @State private var createdIngredientIDs: [UUID] = []
  /// Surfaces a "save failed, try again" alert so a thrown `modelContext.save()`
  /// isn't an invisible no-op for the user.
  @State private var showSaveError = false
  /// Medications inserted by the just-completed import, handed to the bundled
  /// meal-assignment step. Empty until `performImport` succeeds.
  @State private var importedMedications: [Medication] = []
  @State private var showMealAssignment = false

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
        Section {
          ForEach(library) { ingredient in
            row(draft: draft, ingredient: ingredient)
          }
          addNewRow(for: draft)
        } header: {
          VStack(alignment: .leading, spacing: 2) {
            LiquidGlassTheme.Typography.medicationName(draft.displayName)
              .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
              .textCase(nil)
            LiquidGlassTheme.Typography.footnote("Pick the ingredients this product contains.")
              .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
              .textCase(nil)
          }
          .padding(.vertical, LiquidGlassTheme.Spacing.compact)
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .glassBackground()
    .navigationTitle("Confirm Components")
    .toolbarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") { cancel() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Import") { performImport() }
          .disabled(!Self.canImport(drafts: drafts, selections: selections))
      }
    }
    .alert("Import failed", isPresented: $showSaveError) {
      Button("OK", role: .cancel) { showSaveError = false }
    } message: {
      Text("Couldn't save the imported medications. Please try again.")
    }
    .sheet(isPresented: $showMealAssignment) {
      PillMealAssignmentSheet(
        medications: importedMedications,
        meals: pillMeals,
        onFinish: onComplete
      )
    }
    .onAppear(perform: applyAutoSuggestions)
  }

  /// Gates the Import button: every draft must have at least one ingredient
  /// selected. Without this guard a user can persist a `Medication` with zero
  /// `MedicationComponent`s, which leaves the PRN-ceiling logic with nothing to
  /// aggregate and the watch UI with an untappable row.
  static func canImport(drafts: [MedicationDraft], selections: [UUID: Set<UUID>]) -> Bool {
    !drafts.isEmpty && drafts.allSatisfy { !(selections[$0.id]?.isEmpty ?? true) }
  }

  private func row(draft: MedicationDraft, ingredient: Ingredient) -> some View {
    let isSelected = selections[draft.id, default: []].contains(ingredient.id)
    return Button {
      toggle(ingredient: ingredient.id, for: draft.id)
    } label: {
      HStack(spacing: LiquidGlassTheme.Spacing.compact) {
        VStack(alignment: .leading, spacing: 2) {
          LiquidGlassTheme.Typography.headline(ingredient.name)
            .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
          if !ingredient.aliases.isEmpty {
            LiquidGlassTheme.Typography.footnote(ingredient.aliases.joined(separator: ", "))
              .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          }
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? LiquidGlassTheme.Colors.primaryText : LiquidGlassTheme.Colors.secondaryText)
          .accessibilityLabel(isSelected ? "Selected" : "Not selected")
      }
      .padding(.vertical, LiquidGlassTheme.Spacing.compact / 2)
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
    var inserted: [Medication] = []
    for draft in drafts {
      // Three safety-relevant gaps the user must close in the regimen UI after
      // import — none is derivable from the Health side:
      //
      //   - `unitForm: .tablet` is a placeholder. HealthKit's
      //     `HKMedicationGeneralForm` exposes capsules / liquids / patches /
      //     etc., but mapping it cleanly is out of scope here; the user picks
      //     the correct form on `EditMedicationView`.
      //   - `kind: .maintenance` is a placeholder. An imported PRN med
      //     silently becomes maintenance until the user corrects it — relevant
      //     for products like gabapentin that ship with PRN UX.
      //   - High-risk medications (lithium is the SPEC example) require
      //     press-and-hold confirmation on the watch. `Medication.isHighRisk`
      //     is computed from the ingredients' `isHighRisk` flag, and the
      //     seeded library is OTC-only (no flagged ingredients), so a newly
      //     imported lithium product comes through low-risk and gets the
      //     single-tap gesture until the user marks its ingredient as
      //     high-risk in the Ingredients screen. A post-import safety-flag
      //     prompt is a follow-up issue; until then this is documented.
      let medication = Medication(
        displayName: draft.displayName,
        unitForm: .tablet,
        kind: .maintenance,
        healthKitConceptID: draft.healthKitConceptID
      )
      modelContext.insert(medication)
      inserted.append(medication)
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
      // Default `.private` redaction — SwiftData/Core Data error descriptions
      // can embed model-object summaries that include medication names.
      Self.logger.error("Health import save failed: \(error.localizedDescription)")
      modelContext.rollback()
      InlineIngredientCleanup.discardUnreferenced(createdIngredientIDs, in: modelContext)
      // Surface the failure rather than leaving the user staring at an
      // unchanged screen wondering whether Import did anything.
      showSaveError = true
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    // §8.4: if the user already has Pill Meals, offer to assign the freshly
    // imported meds in one bundled step before tearing down the import flow.
    // With no meals there's nothing to assign to, so finish immediately.
    if pillMeals.isEmpty {
      // `onComplete` dismisses the entire import sheet, which tears down the
      // NavigationStack this view lives in. A second `dismiss()` here would
      // target an already-departing parent.
      onComplete()
    } else {
      importedMedications = inserted
      showMealAssignment = true
    }
  }
}
