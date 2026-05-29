import os
import SwiftData
import SwiftUI
import UserNotifications
import WatchKit

/// Opened when the "Snooze until…" notification action fires (SPEC §2.2, §8.3).
/// Pick a wall-clock time; Done reschedules the dose via `SnoozeRescheduler` and
/// dismisses. The live label shows the resolved fire time, flagging a roll into
/// tomorrow. Default is 30 minutes out (promoted to a user preference in
/// EPIC_06_ISSUE_05).
struct SnoozeView: View {
  let context: SnoozeContext

  /// Default snooze offset; becomes a `UserPreferences` value in EPIC_06_ISSUE_05.
  static let defaultOffset: TimeInterval = 30 * 60

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var snoozeTime: Date = .now.addingTimeInterval(SnoozeView.defaultOffset)
  @State private var rescheduleFailed = false
  @State private var route: SnoozeRoute = .picker
  @State private var snoozeCount = 0

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "Snooze")

  var body: some View {
    Group {
      switch route {
      case .warning:
        SnoozeWarningView(
          context: context,
          snoozeCount: snoozeCount,
          onSnoozeAgain: { route = .picker },
          onResolved: { dismiss() }
        )
      case .picker:
        picker
      }
    }
    .onAppear {
      let count = currentSnoozeCount()
      snoozeCount = count
      route = SnoozeViewRouter.routeForCount(count)
    }
  }

  private var picker: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      DatePicker("Snooze until", selection: $snoozeTime, displayedComponents: .hourAndMinute)
        .labelsHidden()

      LiquidGlassTheme.Typography.caption(Self.targetLabel(for: snoozeTime, now: .now, calendar: .current))
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .multilineTextAlignment(.center)

      HStack(spacing: LiquidGlassTheme.Spacing.standard) {
        Button("Cancel") { dismiss() }
          .buttonStyle(.bordered)
        Button("Done") { Task { await confirm() } }
          .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
    .alert("Couldn't snooze", isPresented: $rescheduleFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("The reminder couldn't be rescheduled. Try again.")
    }
  }

  private func currentSnoozeCount() -> Int {
    (try? SnoozeRecordStore.currentCount(scheduledDoseID: context.scheduledDoseID, on: .now, in: modelContext)) ?? 0
  }

  private func confirm() async {
    let components = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)
    do {
      try await SnoozeRescheduler.snooze(
        scheduledDoseID: context.scheduledDoseID,
        originalScheduledFor: context.originalScheduledFor,
        medicationName: context.medicationName,
        snoozeUntil: components,
        now: .now,
        center: UNUserNotificationCenter.current(),
        context: modelContext
      )
      dismiss()
    } catch {
      // Don't dismiss on failure: surface it (a silently-missed snooze is the worst
      // outcome) so the user can retry from the still-open sheet.
      SnoozeView.logger.error("Failed to reschedule snooze: \(error.localizedDescription, privacy: .public)")
      WKInterfaceDevice.current().play(.failure)
      rescheduleFailed = true
    }
  }

  /// "Will fire 10:17 PM today" / "…tomorrow" — pure so it's unit-testable.
  static func targetLabel(for pickedTime: Date, now: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.hour, .minute], from: pickedTime)
    guard let target = try? SnoozeRescheduler.resolveTarget(from: components, now: now, calendar: calendar) else {
      return "Pick a time"
    }
    let timeText = target.formatted(date: .omitted, time: .shortened)
    let day = calendar.isDate(target, inSameDayAs: now) ? "today" : "tomorrow"
    return "Will fire \(timeText) \(day)"
  }
}

#Preview {
  SnoozeView(context: SnoozeContext(
    scheduledDoseID: UUID(),
    originalScheduledFor: .now,
    medicationName: "Vitamin D"
  ))
}
