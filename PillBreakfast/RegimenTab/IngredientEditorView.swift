import os
import SwiftData
import SwiftUI

/// Edits an existing ingredient's safety thresholds and high-risk flag *or*
/// creates a new one. Mode is selected at init: `init(ingredient:)` for edit
/// (the existing path), `init(creatingNamed:)` for create.
///
/// In edit mode, the seeded-threshold disclaimer is shown and on save the
/// regimen snapshot is re-pushed to the watch. Create mode inserts a fresh
/// `Ingredient` into the context with the entered values, then dismisses.
///
/// Seeded library ingredients are intentionally editable here — their
/// thresholds are *personal* ceilings, not read-only canonical values. Only
/// their deletion is blocked (see `IngredientDeletion`).
struct IngredientEditorView: View {
  /// Internal mode for the editor — distinguishes edit-an-existing from
  /// create-a-new without forking the view body.
  private enum Mode {
    case edit(Ingredient)
    case create
  }

  private let mode: Mode

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var nameText: String
  @State private var ceilingText: String
  @State private var intervalText: String
  @State private var isHighRisk: Bool
  @State private var saveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  /// Edit an existing ingredient. Preserves the prior call-site shape.
  init(ingredient: Ingredient) {
    self.mode = .edit(ingredient)
    // Edit mode never surfaces a Name field (renaming would need a
    // duplicate-name guard and migration of `stableUUID`-derived seed
    // IDs); the `@State` is initialised empty just to satisfy the
    // declaration.
    _nameText = State(initialValue: "")
    _ceilingText = State(initialValue: ingredient.dailyCeilingMg.map { String(Int($0.rounded())) } ?? "")
    _intervalText = State(initialValue: ingredient.minIntervalMinutes.map(String.init) ?? "")
    _isHighRisk = State(initialValue: ingredient.isHighRisk)
  }

  /// Create a new ingredient, optionally pre-filling the name (e.g. from a
  /// search-miss row that funnels the typed query into the editor).
  init(creatingNamed initialName: String = "") {
    self.mode = .create
    _nameText = State(initialValue: initialName)
    _ceilingText = State(initialValue: "")
    _intervalText = State(initialValue: "")
    _isHighRisk = State(initialValue: false)
  }

  var body: some View {
    Form {
      if case .create = mode {
        Section {
          // `.never` so a user typing "lithium carbonate" doesn't get
          // silently transformed to "Lithium Carbonate" (title case) when
          // canonical drug naming is sentence case ("Lithium carbonate").
          // Autocorrect off because chemical names break it.
          TextField("Acetaminophen, Vitamin D3, …", text: $nameText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } header: {
          LiquidGlassTheme.Typography.headline("Name")
            .textCase(nil)
        } footer: {
          LiquidGlassTheme.Typography.footnote("Use the canonical drug name; add brand names and synonyms separately later.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      } else if case let .edit(ingredient) = mode, !ingredient.aliases.isEmpty {
        Section {
          LiquidGlassTheme.Typography.footnote(ingredient.aliases.joined(separator: ", "))
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        } header: {
          LiquidGlassTheme.Typography.headline("Aliases")
            .textCase(nil)
        }
      }

      Section {
        TextField("e.g. 4000", text: $ceilingText)
          .keyboardType(.numberPad)
          .font(LiquidGlassTheme.Typography.dosageFont)
      } header: {
        LiquidGlassTheme.Typography.headline("Daily ceiling (mg)")
          .textCase(nil)
      } footer: {
        LiquidGlassTheme.Typography.footnote("Leave blank for no ceiling.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }

      Section {
        TextField("e.g. 240", text: $intervalText)
          .keyboardType(.numberPad)
          .font(LiquidGlassTheme.Typography.dosageFont)
      } header: {
        LiquidGlassTheme.Typography.headline("Minimum interval (minutes)")
          .textCase(nil)
      } footer: {
        LiquidGlassTheme.Typography.footnote("Leave blank for no spacing rule.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }

      Section {
        Toggle("High risk", isOn: $isHighRisk)
      } footer: {
        LiquidGlassTheme.Typography.footnote("Toggling this on requires press-and-hold to confirm every product containing this ingredient.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }

      Section {
        LiquidGlassTheme.Typography.footnote(IngredientLibrarySeeder.disclaimer)
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
    }
    .scrollContentBackground(.hidden)
    .glassBackground()
    .navigationTitle(navigationTitle)
    .toolbarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(saveButtonTitle, action: save)
          // Don't let a non-numeric entry save silently as "no change" — block it.
          .disabled(!isValid)
      }
      if case .create = mode {
        // A modally-presented create sheet needs an explicit dismiss.
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
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

  private var navigationTitle: String {
    switch mode {
    case let .edit(ingredient): ingredient.name
    case .create: "New Ingredient"
    }
  }

  private var saveButtonTitle: String {
    switch mode {
    case .edit: "Save"
    case .create: "Add"
    }
  }

  /// Parsed thresholds, or `nil` if a field is non-empty but unparseable. A blank
  /// field means "no threshold". Single source of truth for both `isValid` and
  /// `save()` so the validation and save paths can't diverge.
  private var parsedThresholds: (ceiling: Double?, interval: Int?)? {
    func parse<T>(_ text: String, _ convert: (String) -> T?) -> T?? {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return .some(nil) } // blank → no threshold
      guard let value = convert(trimmed) else { return nil } // non-numeric → invalid
      return .some(value)
    }
    guard let ceiling = parse(ceilingText, Double.init),
          let interval = parse(intervalText, Int.init)
    else { return nil }
    return (ceiling, interval)
  }

  /// Save is blocked when a field is non-empty but unparseable, so a typo can't
  /// masquerade as "no change". In create mode also requires a non-empty name.
  private var isValid: Bool {
    guard parsedThresholds != nil else { return false }
    if case .create = mode {
      return !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return true
  }

  private func save() {
    // `isValid` gates the Save button, so this is non-nil here.
    guard let thresholds = parsedThresholds else { return }
    switch mode {
    case let .edit(ingredient):
      ingredient.dailyCeilingMg = thresholds.ceiling
      ingredient.minIntervalMinutes = thresholds.interval
      ingredient.isHighRisk = isHighRisk
    case .create:
      let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
      // Block duplicate-name inserts. Safety totals key on `Ingredient`
      // identity, so two rows with the same name silently fork the
      // per-ingredient ceiling — neither would ever fire on a real
      // overdose. Match delegated to `IngredientFilter.containsName`
      // (case-insensitive) so it's covered by unit tests.
      let existing: [Ingredient]
      do {
        existing = try modelContext.fetch(FetchDescriptor<Ingredient>())
      } catch {
        // Don't silently fall through to an empty `existing` — that would
        // defeat the duplicate guard. Surface the failure and bail.
        IngredientEditorView.logger.error(
          "Duplicate-check fetch failed: \(error.localizedDescription, privacy: .public)"
        )
        saveError = "Couldn't verify the ingredient name. Please try again."
        return
      }
      if IngredientFilter.containsName(trimmedName, in: existing) {
        saveError = "An ingredient named \"\(trimmedName)\" already exists. Edit that one instead."
        return
      }
      let new = Ingredient(
        name: trimmedName,
        isHighRisk: isHighRisk,
        dailyCeilingMg: thresholds.ceiling,
        minIntervalMinutes: thresholds.interval
      )
      modelContext.insert(new)
    }

    do {
      try modelContext.save()
    } catch {
      IngredientEditorView.logger.error("Failed to save ingredient edit: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
      return
    }
    // Only push when an existing ingredient's thresholds actually changed —
    // a freshly-created Ingredient has no medication assignments yet, so its
    // insert doesn't change the `RegimenSnapshot` (which carries medications
    // + components). The subsequent medication save will push when the
    // ingredient gets wired into a product.
    if case .edit = mode {
      WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    }
    dismiss()
  }
}
