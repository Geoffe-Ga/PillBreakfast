import SwiftData
import SwiftUI

/// Shared form fields for adding and editing a maintenance medication. PRN
/// configuration is intentionally stubbed here (EPIC 05).
struct MedicationFormView: View {
  @Bindable var formState: MedicationFormState
  /// Called with the id of an ingredient created inline, so the host can clean it
  /// up if the medication is never saved.
  var onIngredientCreated: (UUID) -> Void = { _ in }
  @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
  @State private var showingNewIngredient = false
  /// Sticky once the user first touches the form, so errors don't vanish if a
  /// field (e.g. the name) is later cleared back to empty.
  @State private var hasInteracted = false

  var body: some View {
    Form {
      Section("Medication") {
        TextField("Name", text: $formState.displayName)
        Picker("Form", selection: $formState.unitForm) {
          ForEach(MedicationForm.allCases, id: \.self) { form in
            Text(form.rawValue.capitalized).tag(form)
          }
        }
      }

      Section("Ingredient") {
        Picker("Ingredient", selection: $formState.componentDraft.ingredientID) {
          Text("Select…").tag(UUID?.none)
          ForEach(ingredients) { ingredient in
            Text(ingredient.name).tag(UUID?.some(ingredient.id))
          }
        }
        Button("New Ingredient…") { showingNewIngredient = true }
        HStack {
          Text("Dose per unit (mg)")
          Spacer()
          TextField("mg", value: $formState.componentDraft.dosagePerUnitMg, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
      }

      if formState.kind == .maintenance {
        Section("Schedule") {
          ScheduleRowEditor(schedules: $formState.schedules)
        }
      }

      if hasInteracted, !formState.validationErrors.isEmpty {
        Section {
          ForEach(formState.validationErrors, id: \.self) { error in
            Text(error)
              .font(LiquidGlassTheme.Typography.captionFont)
              // Semantic error color, not decoration — kept deliberately. Color
              // discipline (amber-only) governs the watch logging surface; an
              // error indicator on the iPhone setup form is a different concern.
              .foregroundStyle(.red)
          }
        }
      }

      if formState.kind == .prn {
        PRNFormSection(formState: formState)
      }

      Section {
        NavigationLink {
          IngredientsListView()
        } label: {
          Label("Manage ingredients", systemImage: "list.bullet.rectangle")
        }
      } footer: {
        Text("Edit safety ceilings, spacing, and high-risk flags for ingredients.")
      }
    }
    .scrollContentBackground(.hidden)
    .glassBackground()
    .sheet(isPresented: $showingNewIngredient) {
      NewIngredientView { newID in
        formState.componentDraft.ingredientID = newID
        onIngredientCreated(newID)
      }
    }
    .onChange(of: formState.displayName) { _, _ in hasInteracted = true }
    .onChange(of: formState.componentDraft) { _, _ in hasInteracted = true }
    .onChange(of: formState.schedules) { _, _ in hasInteracted = true }
  }
}

/// One-screen sub-form for adding an ingredient to the library inline.
private struct NewIngredientView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let onCreate: (UUID) -> Void

  @State private var name = ""
  @State private var isHighRisk = false

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespaces)
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
        Toggle("High-risk (press-and-hold to confirm)", isOn: $isHighRisk)
      }
      .navigationTitle("New Ingredient")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            let ingredient = Ingredient(name: trimmedName, isHighRisk: isHighRisk)
            modelContext.insert(ingredient)
            onCreate(ingredient.id)
            dismiss()
          }
          .disabled(trimmedName.isEmpty)
        }
      }
    }
  }
}
