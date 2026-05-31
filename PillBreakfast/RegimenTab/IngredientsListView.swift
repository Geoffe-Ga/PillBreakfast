import os
import SwiftData
import SwiftUI

/// iPhone Ingredients screen: the library of safety thresholds the user is
/// responsible for. The seeded-threshold disclaimer sits permanently at the top
/// (non-dismissible). Seeded entries can't be deleted; user-added ones can be,
/// but only when no medication still references them.
///
/// `.searchable` filters in-memory by name + aliases (case-insensitive) via
/// `IngredientFilter`; the same helper feeds the medication-editor picker so
/// the two surfaces can't drift on filter rules. A `+` toolbar item and a
/// search-miss row both route into `IngredientEditorView`'s create mode.
struct IngredientsListView: View {
  /// Sub-compact inter-line spacing so name + threshold summary hug as one row.
  private static let rowLineSpacing: CGFloat = 2

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
  @State private var deleteError: String?
  @State private var searchText = ""
  @State private var creationPresentation: CreationPresentation?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  var body: some View {
    let filtered = IngredientFilter.filter(ingredients, query: searchText)
    let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let showAddRow = !trimmedQuery.isEmpty && filtered.isEmpty
    List {
      Section {
        disclaimerCard
          .listRowInsets(EdgeInsets(top: LiquidGlassTheme.Spacing.compact, leading: 0, bottom: LiquidGlassTheme.Spacing.standard, trailing: 0))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }

      if showAddRow {
        Section {
          Button {
            creationPresentation = CreationPresentation(initialName: trimmedQuery)
          } label: {
            Label("Add \"\(trimmedQuery)\" as new ingredient", systemImage: "plus.circle.fill")
          }
        }
      }

      Section {
        ForEach(filtered) { ingredient in
          NavigationLink {
            IngredientEditorView(ingredient: ingredient)
          } label: {
            row(ingredient)
          }
        }
        .onDelete { offsets in delete(at: offsets, in: filtered) }
      } header: {
        LiquidGlassTheme.Typography.headline("Ingredients")
          .textCase(nil)
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .glassBackground()
    .navigationTitle("Ingredients")
    .searchable(text: $searchText, prompt: "Search by name or alias")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          creationPresentation = CreationPresentation(initialName: "")
        } label: {
          Label("Add ingredient", systemImage: "plus")
        }
      }
    }
    .sheet(item: $creationPresentation) { presentation in
      NavigationStack {
        IngredientEditorView(creatingNamed: presentation.initialName)
      }
    }
    .alert(
      "Can't delete",
      isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
    ) {
      Button("OK", role: .cancel) { deleteError = nil }
    } message: {
      Text(deleteError ?? "")
    }
  }

  /// "Important" lead-in + the seeded-threshold disclaimer, wrapped in an
  /// elevated glass card so the safety statement reads as earnest rather
  /// than buried boilerplate.
  private var disclaimerCard: some View {
    VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
      LiquidGlassTheme.Typography.headline("Important")
        .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
      LiquidGlassTheme.Typography.footnote(IngredientLibrarySeeder.disclaimer)
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
    .padding(LiquidGlassTheme.Spacing.standard)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LiquidGlassTheme.Materials.surface)
    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.card))
    .elevation(.raised)
  }

  private func row(_ ingredient: Ingredient) -> some View {
    HStack(alignment: .center, spacing: LiquidGlassTheme.Spacing.compact) {
      VStack(alignment: .leading, spacing: Self.rowLineSpacing) {
        LiquidGlassTheme.Typography.medicationName(ingredient.name)
        LiquidGlassTheme.Typography.footnote(thresholdSummary(ingredient))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
      Spacer(minLength: 0)
      if ingredient.isHighRisk {
        highRiskBadge
      }
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  /// Sub-compact inter-element padding for chip-shaped elements — half the
  /// `Spacing.compact` rhythm so the chip stays a single visual unit rather
  /// than reading as a button.
  private static let chipInnerPadding: CGFloat = 4

  /// Monochrome chip — CLAUDE.md reserves the amber accent for the
  /// press-and-hold watch surface, so the iPhone setup indicator stays
  /// glyph-and-text only.
  private var highRiskBadge: some View {
    HStack(spacing: Self.chipInnerPadding) {
      Image(systemName: "exclamationmark.shield.fill")
      LiquidGlassTheme.Typography.caption("High risk")
    }
    .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    .padding(.horizontal, LiquidGlassTheme.Spacing.compact)
    .padding(.vertical, Self.chipInnerPadding)
    .background(LiquidGlassTheme.Materials.surface)
    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.tight))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("High risk")
  }

  private func thresholdSummary(_ ingredient: Ingredient) -> String {
    var parts: [String] = []
    if let ceiling = ingredient.dailyCeilingMg { parts.append("\(Int(ceiling.rounded())) mg/day") }
    if let interval = ingredient.minIntervalMinutes { parts.append("\(interval) min spacing") }
    return parts.isEmpty ? "No limits set" : parts.joined(separator: " · ")
  }

  /// `offsets` indexes into the *filtered* view the user sees, not the full
  /// `ingredients` array — without this, deleting the third visible row while
  /// a filter is active would delete the third row of the *unfiltered* list.
  private func delete(at offsets: IndexSet, in visible: [Ingredient]) {
    for index in offsets {
      let ingredient = visible[index]
      do {
        switch try IngredientDeletion.check(ingredient, in: modelContext) {
        case .seeded:
          deleteError = "Seeded library ingredients can't be deleted."
          continue
        case .referenced:
          deleteError = "\(ingredient.name) is used by a medication — remove it there first."
          continue
        case .allowed:
          break
        }
        modelContext.delete(ingredient)
        try modelContext.save()
        WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
      } catch {
        IngredientsListView.logger.error("Failed to delete ingredient: \(error.localizedDescription, privacy: .public)")
        modelContext.rollback()
        deleteError = "The change couldn't be saved. Please try again."
      }
    }
  }
}

/// Sheet payload for the create-ingredient flow. `Identifiable` so a fresh
/// presentation always re-presents the sheet (changing `initialName` would
/// otherwise be a no-op for SwiftUI's identity-based sheet binding).
private struct CreationPresentation: Identifiable {
  let id = UUID()
  let initialName: String
}

#Preview {
  NavigationStack {
    IngredientsListView()
  }
  // Medication pulls in the related Ingredient/MedicationComponent models, so the
  // preview container matches the live schema breadth (deletion checks touch
  // MedicationComponent).
  .modelContainer(for: Medication.self, inMemory: true)
}
