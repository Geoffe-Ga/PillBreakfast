import os
import SwiftData
import SwiftUI

/// Bundled "Add to Pill Meals?" step shown once after a HealthKit import saves
/// (SPEC §8.4). Imported meds arrive without a schedule, so each row offers a
/// meal picker (or "None"); Save synthesises a `ScheduledDose` at the chosen
/// meal's target time for every picked row (see `PillMealAssignment`). "Skip
/// all" finishes without assigning. Only presented when the user already has at
/// least one Pill Meal — otherwise there's nothing to assign to.
struct PillMealAssignmentSheet: View {
  let medications: [Medication]
  let meals: [PillMeal]
  /// Called when the user finishes — Save (after assignment) or Skip all. Tears
  /// down the whole import flow, same as `ConfirmComponentsView.onComplete`.
  let onFinish: () -> Void

  @Environment(\.modelContext) private var modelContext

  /// medication.id → chosen meal id. Absent or `nil` means "None".
  @State private var selections: [UUID: UUID] = [:]
  @State private var saveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "HealthImport")

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(medications) { medication in
            row(for: medication)
          }
        } header: {
          LiquidGlassTheme.Typography.headline("Add to Pill Meals?")
            .textCase(nil)
        } footer: {
          LiquidGlassTheme.Typography.footnote("Picking a meal schedules this medication at that meal's time. Leave a row on \"None\" to set its schedule yourself later.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .glassBackground()
      .navigationTitle("Pill Meals")
      .toolbarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Skip all") { onFinish() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
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

  private func row(for medication: Medication) -> some View {
    Picker(
      selection: Binding(
        get: { selections[medication.id] },
        set: { selections[medication.id] = $0 }
      )
    ) {
      Text("None").tag(UUID?.none)
      ForEach(meals) { meal in
        Text("\(meal.name) · \(Self.timeLabel(hour: meal.targetHour, minute: meal.targetMinute))")
          .tag(UUID?.some(meal.id))
      }
    } label: {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
    }
  }

  private func save() {
    let mealsByID = Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })
    let selectionPairs = medications.map { medication in
      (medication: medication, meal: selections[medication.id].flatMap { mealsByID[$0] })
    }
    do {
      try PillMealAssignment.assignImported(selectionPairs, in: modelContext)
      WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
      onFinish()
    } catch {
      Self.logger.error("Pill Meal assignment save failed: \(error.localizedDescription)")
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
    }
  }

  /// "9:00 AM" via the system formatter; locale-respecting.
  static func timeLabel(hour: Int, minute: Int) -> String {
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: Date())
    let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) ?? midnight
    return date.formatted(date: .omitted, time: .shortened)
  }
}

#Preview {
  PillMealAssignmentSheet(
    medications: [
      Medication(displayName: "Vitamin D", unitForm: .tablet, kind: .maintenance),
      Medication(displayName: "Lithium", unitForm: .tablet, kind: .maintenance),
    ],
    meals: [
      PillMeal(name: "Pill Breakfast", targetHour: 9, targetMinute: 0),
      PillMeal(name: "Pill Dinner", targetHour: 21, targetMinute: 0),
    ],
    onFinish: {}
  )
  .modelContainer(for: [Medication.self, PillMeal.self], inMemory: true)
}
