import SwiftData
import SwiftUI

/// Shared form fields for adding and editing a maintenance medication. PRN
/// configuration is intentionally stubbed here (EPIC 05).
struct MedicationFormView: View {
  @Bindable var formState: MedicationFormState
  /// When `true` (default, push-context), the form applies `.glassBackground()`
  /// as its own glass surface. Pass `false` when embedded in a `.sheet` that
  /// already provides glass chrome at the presentation layer (AddMedicationView),
  /// to avoid a double-glass stack. See issue #103 — revisit if iOS 26 sheet
  /// chrome stops supplying glass.
  var appliesGlassBackground: Bool = true
  /// Called with the id of an ingredient created inline, so the host can clean it
  /// up if the medication is never saved.
  var onIngredientCreated: (UUID) -> Void = { _ in }
  @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
  @Query(sort: [SortDescriptor(\PillMeal.sortOrder), SortDescriptor(\PillMeal.createdAt)])
  private var pillMeals: [PillMeal]
  @State private var showingNewIngredient = false
  /// Pre-fills `NewIngredientView` when the search-miss row in the picker
  /// fires — empties to "" when the `+` New Ingredient button opens it
  /// cold from the form.
  @State private var newIngredientInitialName = ""
  /// Sticky once the user first touches the form, so errors don't vanish if a
  /// field (e.g. the name) is later cleared back to empty.
  @State private var hasInteracted = false

  private var selectedIngredientName: String? {
    guard let id = formState.componentDraft.ingredientID else { return nil }
    return ingredients.first { $0.id == id }?.name
  }

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $formState.displayName)
        Picker("Form", selection: $formState.unitForm) {
          ForEach(MedicationForm.allCases, id: \.self) { form in
            Text(form.rawValue.capitalized).tag(form)
          }
        }
      } header: {
        LiquidGlassTheme.Typography.headline("Medication")
          .textCase(nil)
      }

      Section {
        NavigationLink {
          IngredientPickerView(
            selection: $formState.componentDraft.ingredientID,
            onCreateRequest: { query in
              newIngredientInitialName = query
              showingNewIngredient = true
            }
          )
        } label: {
          HStack {
            Text("Ingredient")
            Spacer()
            Text(selectedIngredientName ?? "Select…")
              .foregroundStyle(selectedIngredientName == nil ? .secondary : .primary)
          }
        }
        Button("New Ingredient…") {
          newIngredientInitialName = ""
          showingNewIngredient = true
        }
        HStack {
          Text("Dose per unit (mg)")
          Spacer()
          TextField("mg", value: $formState.componentDraft.dosagePerUnitMg, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
      } header: {
        LiquidGlassTheme.Typography.headline("Ingredient")
          .textCase(nil)
      }

      if formState.kind == .maintenance {
        Section {
          ScheduleRowEditor(schedules: $formState.schedules, meals: pillMeals)
        } header: {
          LiquidGlassTheme.Typography.headline("Schedule")
            .textCase(nil)
        }
      }

      if hasInteracted, !formState.validationErrors.isEmpty {
        Section {
          ForEach(formState.validationErrors, id: \.self) { error in
            LiquidGlassTheme.Typography.errorText(error)
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
        LiquidGlassTheme.Typography.footnote("Edit safety ceilings, spacing, and high-risk flags for ingredients.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
    }
    .scrollContentBackground(.hidden)
    .if(appliesGlassBackground) { $0.glassBackground() }
    .sheet(isPresented: $showingNewIngredient) {
      NewIngredientView(initialName: newIngredientInitialName) { newID in
        formState.componentDraft.ingredientID = newID
        onIngredientCreated(newID)
      }
    }
    .onChange(of: formState.displayName) { _, _ in hasInteracted = true }
    .onChange(of: formState.componentDraft) { _, _ in hasInteracted = true }
    .onChange(of: formState.schedules) { _, _ in hasInteracted = true }
  }
}

/// One-screen sub-form for adding an ingredient to the library inline from
/// the medication editor's picker (#157). The richer "ceiling + interval +
/// disclaimer" editor lives in `IngredientEditorView` and is reached from the
/// Ingredients tab; this surface stays a lightweight name + high-risk pair.
///
/// `initialName` is pre-filled when the picker's search-miss row routes here.
private struct NewIngredientView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let initialName: String
  let onCreate: (UUID) -> Void

  @State private var name: String
  @State private var isHighRisk = false
  @State private var saveError: String?

  init(initialName: String = "", onCreate: @escaping (UUID) -> Void) {
    self.initialName = initialName
    self.onCreate = onCreate
    _name = State(initialValue: initialName)
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationStack {
      Form {
        TextField("Name", text: $name)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Toggle("High-risk (press-and-hold to confirm)", isOn: $isHighRisk)
      }
      .navigationTitle("New Ingredient")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add", action: add)
            .disabled(trimmedName.isEmpty)
        }
      }
      .alert(
        "Couldn't add",
        isPresented: Binding(
          get: { saveError != nil },
          set: { if !$0 { saveError = nil } }
        )
      ) {
        Button("OK", role: .cancel) { saveError = nil }
      } message: {
        Text(saveError ?? "")
      }
    }
  }

  private func add() {
    // Duplicate-name guard — same invariant as IngredientEditorView's
    // create mode. Two same-name rows would silently fork the per-
    // ingredient safety ceiling and neither would fire on a real overdose.
    // Full fetch (no predicate) is fine at the bounded library size — see
    // the rationale on `IngredientFilter`.
    let existing: [Ingredient]
    do {
      existing = try modelContext.fetch(FetchDescriptor<Ingredient>())
    } catch {
      saveError = "Couldn't verify the ingredient name. Please try again."
      return
    }
    if IngredientFilter.containsName(trimmedName, in: existing) {
      saveError = "An ingredient named \"\(trimmedName)\" already exists. Pick it from the picker instead."
      return
    }
    let ingredient = Ingredient(name: trimmedName, isHighRisk: isHighRisk)
    modelContext.insert(ingredient)
    onCreate(ingredient.id)
    dismiss()
  }
}
