import SwiftData
import SwiftUI

/// Push destination for the medication editor's ingredient slot — replaces the
/// bare `Picker` once the seeded library grew past ~30 entries (#155). Uses
/// the same `IngredientFilter` as `IngredientsListView` so the two surfaces
/// can't drift on filter rules.
///
/// Selection is committed via `selectionBinding`; the search-miss row routes
/// to `onCreateRequest(query)` so the host can present the existing
/// `NewIngredientView` pre-filled with the typed query and chain back into
/// the form's selection.
struct IngredientPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
  @State private var searchText = ""

  let selectionBinding: Binding<UUID?>
  /// Called with the typed search text when the user taps the "Add X as new"
  /// row. The host dismisses the picker and presents the create flow.
  let onCreateRequest: (String) -> Void

  var body: some View {
    let filtered = IngredientFilter.filter(ingredients, query: searchText)
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let showAddRow = !trimmed.isEmpty && filtered.isEmpty
    List {
      if showAddRow {
        Section {
          Button {
            onCreateRequest(trimmed)
            dismiss()
          } label: {
            Label("Add \"\(trimmed)\" as new ingredient", systemImage: "plus.circle.fill")
          }
        }
      }

      Section {
        ForEach(filtered) { ingredient in
          Button {
            selectionBinding.wrappedValue = ingredient.id
            dismiss()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                  .foregroundStyle(.primary)
                if !ingredient.aliases.isEmpty {
                  Text(ingredient.aliases.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              Spacer()
              if selectionBinding.wrappedValue == ingredient.id {
                Image(systemName: "checkmark")
                  .foregroundStyle(.tint)
              }
            }
          }
        }
      } header: {
        Text("Ingredients")
      } footer: {
        if !showAddRow, !ingredients.isEmpty, filtered.isEmpty {
          // Reached when the @Query is non-empty but the *trimmed* query
          // is — defensive; today the filter returns all ingredients on
          // a blank query so this branch is unreachable.
          EmptyView()
        }
      }
    }
    .searchable(text: $searchText, prompt: "Search by name or alias")
    .navigationTitle("Ingredient")
    .navigationBarTitleDisplayMode(.inline)
  }
}
