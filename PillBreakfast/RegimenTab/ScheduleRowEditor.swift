import SwiftUI

/// Editor for a medication's scheduled doses: a row per time with hour/minute,
/// quantity, and an optional Pill Meal binding. When a meal is selected the
/// row's hour/minute are owned by the meal editor and disabled here.
struct ScheduleRowEditor: View {
  @Binding var schedules: [ScheduleDraft]
  /// Sorted by `sortOrder` then `createdAt` upstream so the picker stays
  /// stable across renders.
  var meals: [PillMeal]

  var body: some View {
    ForEach($schedules) { $schedule in
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          DatePicker(
            "Time",
            selection: timeBinding(for: $schedule),
            displayedComponents: .hourAndMinute
          )
          .labelsHidden()
          .disabled(schedule.pillMealID != nil)

          Spacer()

          Text("Qty \(schedule.quantity)")
            .monospacedDigit()
          Stepper(value: $schedule.quantity, in: 1 ... 20) {
            Text("Quantity")
          }
          .labelsHidden()
        }

        if !meals.isEmpty {
          mealPicker(for: $schedule)
        }
      }
    }
    .onDelete { schedules.remove(atOffsets: $0) }

    Button {
      schedules.append(ScheduleDraft())
    } label: {
      Label("Add time", systemImage: "plus.circle")
    }
  }

  /// "Belongs to" picker. Selecting a meal auto-fills hour/minute from the
  /// meal so the schedule row reads consistently with the meal editor; the
  /// DatePicker disables to make the source of truth obvious.
  private func mealPicker(for schedule: Binding<ScheduleDraft>) -> some View {
    Picker("Belongs to", selection: mealBinding(for: schedule)) {
      Text("None").tag(UUID?.none)
      ForEach(meals) { meal in
        Text(meal.name).tag(UUID?.some(meal.id))
      }
    }
    .pickerStyle(.menu)
    .font(LiquidGlassTheme.Typography.footnoteFont)
  }

  /// Setter auto-fills hour/minute when a meal is selected so the disabled
  /// DatePicker still shows the canonical time. Clearing the assignment
  /// re-enables the DatePicker but **does not** revert the time — the user's
  /// next action is to pick a new time, so silently rolling back to a stale
  /// pre-assignment value would be more surprising than leaving the
  /// last-displayed value in place.
  private func mealBinding(for schedule: Binding<ScheduleDraft>) -> Binding<UUID?> {
    Binding<UUID?>(
      get: { schedule.wrappedValue.pillMealID },
      set: { newID in
        schedule.wrappedValue.pillMealID = newID
        if let newID, let meal = meals.first(where: { $0.id == newID }) {
          schedule.wrappedValue.hour = meal.targetHour
          schedule.wrappedValue.minute = meal.targetMinute
        }
      }
    )
  }

  /// Bridges the draft's hour/minute ints to a `Date` for `DatePicker`.
  private func timeBinding(for schedule: Binding<ScheduleDraft>) -> Binding<Date> {
    Binding<Date>(
      get: {
        let midnight = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(
          bySettingHour: schedule.wrappedValue.hour,
          minute: schedule.wrappedValue.minute,
          second: 0,
          of: midnight
        ) ?? midnight
      },
      set: { newDate in
        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
        schedule.wrappedValue.hour = components.hour ?? 0
        schedule.wrappedValue.minute = components.minute ?? 0
      }
    )
  }
}
