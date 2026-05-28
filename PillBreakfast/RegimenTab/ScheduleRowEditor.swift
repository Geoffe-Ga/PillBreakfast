import SwiftUI

/// Editor for a medication's scheduled doses: a row per time with hour/minute and
/// quantity, plus add/remove. Operates on the form state's `[ScheduleDraft]`.
struct ScheduleRowEditor: View {
  @Binding var schedules: [ScheduleDraft]

  var body: some View {
    ForEach($schedules) { $schedule in
      HStack {
        DatePicker(
          "Time",
          selection: timeBinding(for: $schedule),
          displayedComponents: .hourAndMinute
        )
        .labelsHidden()

        Spacer()

        Text("Qty \(schedule.quantity)")
          .monospacedDigit()
        Stepper(value: $schedule.quantity, in: 1 ... 20) {
          Text("Quantity")
        }
        .labelsHidden()
      }
    }
    .onDelete { schedules.remove(atOffsets: $0) }

    Button {
      schedules.append(ScheduleDraft())
    } label: {
      Label("Add time", systemImage: "plus.circle")
    }
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
