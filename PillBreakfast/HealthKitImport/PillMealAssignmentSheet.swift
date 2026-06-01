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
  /// Snapshot of the meals taken when the sheet is presented. Intentional: the
  /// sheet is short-lived and modal, and no path creates a meal while it's up,
  /// so a live `@Query` would add no value over this fixed list.
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
          Button("Skip all") { skipAll() }
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
      // Force exit through Save or Skip all — `ConfirmComponentsView` defers
      // its watch push and `onComplete` to this sheet, so a swipe-down would
      // skip both, leaving the watch out of sync and the import flow orphaned.
      // Same rationale as `AddMedicationView`'s dismiss guard.
      .interactiveDismissDisabled(true)
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
        Text("\(meal.name) · \(PillMealSuggestion.timeLabel(hour: meal.targetHour, minute: meal.targetMinute))")
          .tag(UUID?.some(meal.id))
      }
    } label: {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
    }
  }

  /// Skip all: assign nothing, but still push so the imported (ungrouped) meds
  /// reach the watch — `ConfirmComponentsView` deferred its push to here to
  /// avoid an intermediate push with no meal bindings.
  private func skipAll() {
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
    onFinish()
  }

  private func save() {
    let mealsByID = Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })
    let selectionPairs = medications.map { medication in
      (medication: medication, meal: selections[medication.id].flatMap { mealsByID[$0] })
    }
    do {
      try PillMealAssignment.assignImported(selectionPairs, in: modelContext)
      // Single push for the final state (assignments included), replacing the
      // one `ConfirmComponentsView` used to fire before presenting this sheet.
      WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
      onFinish()
    } catch {
      Self.logger.error("Pill Meal assignment save failed: \(error.localizedDescription)")
      // rollback() only undoes the ScheduledDose inserts above — the imported
      // medications were already committed by ConfirmComponentsView. The sheet
      // stays visible so the user can retry or Skip all.
      modelContext.rollback()
      saveError = "The change couldn't be saved. Please try again."
    }
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
