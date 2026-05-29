import os
import SwiftData
import SwiftUI

/// iPhone Ingredients screen: the library of safety thresholds the user is
/// responsible for. The seeded-threshold disclaimer sits permanently at the top
/// (non-dismissible). Seeded entries can't be deleted; user-added ones can be,
/// but only when no medication still references them.
struct IngredientsListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
  @State private var deleteError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  var body: some View {
    List {
      Section {
        // Non-dismissible by design — the user does not get to hide this.
        Text(IngredientLibrarySeeder.disclaimer)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("Ingredients") {
        ForEach(ingredients) { ingredient in
          NavigationLink {
            IngredientEditorView(ingredient: ingredient)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(ingredient.name)
              Text(thresholdSummary(ingredient))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .onDelete(perform: delete)
      }
    }
    .navigationTitle("Ingredients")
    .alert(
      "Can't delete",
      isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
    ) {
      Button("OK", role: .cancel) { deleteError = nil }
    } message: {
      Text(deleteError ?? "")
    }
  }

  private func thresholdSummary(_ ingredient: Ingredient) -> String {
    var parts: [String] = []
    if let ceiling = ingredient.dailyCeilingMg { parts.append("\(Int(ceiling.rounded())) mg/day") }
    if let interval = ingredient.minIntervalMinutes { parts.append("\(interval) min spacing") }
    if ingredient.isHighRisk { parts.append("high risk") }
    return parts.isEmpty ? "No limits set" : parts.joined(separator: " · ")
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      let ingredient = ingredients[index]
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

#Preview {
  NavigationStack {
    IngredientsListView()
  }
  // Medication pulls in the related Ingredient/MedicationComponent models, so the
  // preview container matches the live schema breadth (deletion checks touch
  // MedicationComponent).
  .modelContainer(for: Medication.self, inMemory: true)
}
