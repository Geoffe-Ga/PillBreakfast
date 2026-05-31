import os
import SwiftData
import SwiftUI

/// Create / edit / delete a `PillMeal`. Saving propagates a target-time change
/// to every assigned `ScheduledDose` (the meal owns the time once a dose is
/// assigned to it). Delete is gated by `PillMealDeletion.check` — same shape
/// as `IngredientDeletion`.
struct PillMealEditorView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  /// `nil` = create mode, non-nil = edit mode.
  let existing: PillMeal?

  @State private var name: String
  @State private var time: Date
  @State private var saveError: String?
  @State private var deleteBlockedCount: Int?
  @State private var hasInteracted = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "PillMealEdit")

  init(existing: PillMeal? = nil) {
    self.existing = existing
    let midnight = Calendar.current.startOfDay(for: Date())
    if let existing {
      _name = State(initialValue: existing.name)
      _time = State(initialValue: Calendar.current.date(
        bySettingHour: existing.targetHour,
        minute: existing.targetMinute,
        second: 0,
        of: midnight
      ) ?? midnight)
    } else {
      _name = State(initialValue: "")
      _time = State(initialValue: Calendar.current.date(
        bySettingHour: 9, minute: 30, second: 0, of: midnight
      ) ?? midnight)
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var nameError: String? {
    trimmedName.isEmpty ? "Name required." : nil
  }

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $name)
          .textInputAutocapitalization(.words)
        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
      } header: {
        LiquidGlassTheme.Typography.headline("Pill Meal")
          .textCase(nil)
      }

      if hasInteracted, let nameError {
        Section {
          LiquidGlassTheme.Typography.footnote(nameError)
            .foregroundStyle(.red)
        }
      }

      if existing != nil {
        Section {
          Button(role: .destructive, action: attemptDelete) {
            Label("Delete Pill Meal", systemImage: "trash")
          }
        } footer: {
          if let count = deleteBlockedCount, count > 0 {
            LiquidGlassTheme.Typography.footnote(
              "Reassign or remove the \(count) scheduled \(count == 1 ? "dose" : "doses") on this meal before deleting."
            )
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          }
        }
      }
    }
    .scrollContentBackground(.hidden)
    .glassBackground()
    .navigationTitle(existing == nil ? "New Pill Meal" : "Edit Pill Meal")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: save)
          .disabled(nameError != nil)
      }
    }
    .onChange(of: name) { _, _ in hasInteracted = true }
    .alert(
      "Couldn't save",
      isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("OK", role: .cancel) { saveError = nil }
    } message: {
      Text(saveError ?? "")
    }
  }

  private func save() {
    let components = Calendar.current.dateComponents([.hour, .minute], from: time)
    let newHour = components.hour ?? 0
    let newMinute = components.minute ?? 0
    do {
      if let existing {
        existing.name = trimmedName
        existing.applyTime(targetHour: newHour, targetMinute: newMinute)
        try modelContext.save()
      } else {
        let meal = PillMeal(
          name: trimmedName,
          targetHour: newHour,
          targetMinute: newMinute
        )
        modelContext.insert(meal)
        try modelContext.save()
      }
      WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
      dismiss()
    } catch {
      PillMealEditorView.logger.error("Failed to save pill meal: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
    }
  }

  private func attemptDelete() {
    guard let existing else { return }
    switch PillMealDeletion.check(existing) {
    case .allowed:
      do {
        modelContext.delete(existing)
        try modelContext.save()
        WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
        dismiss()
      } catch {
        PillMealEditorView.logger.error("Pill meal delete failed: \(error.localizedDescription, privacy: .public)")
        modelContext.rollback()
        saveError = "The change couldn't be saved. Please try again."
      }
    case let .referenced(count):
      deleteBlockedCount = count
    }
  }
}

#Preview {
  NavigationStack {
    PillMealEditorView()
  }
  .modelContainer(for: PillMeal.self, inMemory: true)
}
