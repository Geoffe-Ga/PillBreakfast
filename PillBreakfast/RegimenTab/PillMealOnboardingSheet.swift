import os
import SwiftData
import SwiftUI

/// First-launch "we found N pill groups in your regimen" sheet (SPEC §8.1).
/// One card per suggested cluster: an editable name (pre-filled with the
/// heuristic), the cluster's target time, and its medication names. Save
/// materialises a `PillMeal` and assigns the cluster's doses; Skip leaves the
/// cluster untouched. The `pillMealsOnboarded` flag flips on dismiss (handled
/// by the presenter's `.sheet(onDismiss:)`) regardless of the save/skip mix.
struct PillMealOnboardingSheet: View {
  let suggestions: [SuggestedMeal]

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  /// Per-row edited names, keyed by suggestion id and seeded with the
  /// heuristic name. A row not in the map falls back to its `suggestedName`.
  @State private var editedNames: [UUID: String]
  @State private var savedIDs: Set<UUID> = []
  @State private var skippedIDs: Set<UUID> = []
  @State private var saveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "PillMealOnboarding")

  init(suggestions: [SuggestedMeal]) {
    self.suggestions = suggestions
    _editedNames = State(initialValue: Dictionary(
      suggestions.map { ($0.id, $0.suggestedName) },
      uniquingKeysWith: { first, _ in first }
    ))
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(suggestions) { suggestion in
            row(for: suggestion)
          }
        } header: {
          LiquidGlassTheme.Typography.headline("Suggested Pill Meals")
            .textCase(nil)
        } footer: {
          LiquidGlassTheme.Typography.footnote("Name and save the groups you want — skip any you don't. You can edit these later in the Regimen tab.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      }
      .scrollContentBackground(.hidden)
      .glassBackground()
      .navigationTitle("Pill Meals")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
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
  }

  private func row(for suggestion: SuggestedMeal) -> some View {
    VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.compact) {
      LiquidGlassTheme.Typography.footnote("\(Self.timeLabel(hour: suggestion.hour, minute: suggestion.minute)) · \(suggestion.medicationNames.joined(separator: " · "))")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)

      if savedIDs.contains(suggestion.id) {
        Label(name(for: suggestion), systemImage: "checkmark.circle.fill")
          .font(.body)
      } else if skippedIDs.contains(suggestion.id) {
        LiquidGlassTheme.Typography.medicationName("Skipped")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      } else {
        TextField("Name", text: binding(for: suggestion))
          .textInputAutocapitalization(.words)
        HStack {
          Button("Skip") { skip(suggestion) }
            .buttonStyle(.bordered)
          Spacer()
          Button("Save") { save(suggestion) }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedName(for: suggestion).isEmpty)
        }
      }
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  private func binding(for suggestion: SuggestedMeal) -> Binding<String> {
    Binding(
      get: { editedNames[suggestion.id] ?? suggestion.suggestedName },
      set: { editedNames[suggestion.id] = $0 }
    )
  }

  private func name(for suggestion: SuggestedMeal) -> String {
    editedNames[suggestion.id] ?? suggestion.suggestedName
  }

  private func trimmedName(for suggestion: SuggestedMeal) -> String {
    name(for: suggestion).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func skip(_ suggestion: SuggestedMeal) {
    skippedIDs.insert(suggestion.id)
  }

  private func save(_ suggestion: SuggestedMeal) {
    let trimmed = trimmedName(for: suggestion)
    guard !trimmed.isEmpty else { return }
    // persist(_:in:) uses suggestedName as the meal name; rebuild with trimmed input.
    let named = SuggestedMeal(
      id: suggestion.id,
      suggestedName: trimmed,
      hour: suggestion.hour,
      minute: suggestion.minute,
      doseIDs: suggestion.doseIDs,
      medicationNames: suggestion.medicationNames
    )
    do {
      try PillMealOnboardingService.persist(named, in: modelContext)
      WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
      savedIDs.insert(suggestion.id)
    } catch {
      Self.logger.error("Failed to save suggested pill meal: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
    }
  }

  /// "9:30 AM" via the system formatter; locale-respecting.
  static func timeLabel(hour: Int, minute: Int) -> String {
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: Date())
    let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) ?? midnight
    return date.formatted(date: .omitted, time: .shortened)
  }
}

#Preview {
  PillMealOnboardingSheet(
    suggestions: [
      SuggestedMeal(suggestedName: "Pill Breakfast", hour: 9, minute: 30, doseIDs: [UUID(), UUID()], medicationNames: ["Vitamin D", "Lithium", "B12"]),
      SuggestedMeal(suggestedName: "Pill Dinner", hour: 21, minute: 0, doseIDs: [UUID(), UUID(), UUID()], medicationNames: ["Lithium", "Lamictal"]),
    ]
  )
}
