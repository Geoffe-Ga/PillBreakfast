import os
import SwiftData
import SwiftUI

/// Watch root. Routes to the tap-through queue when doses are pending, else
/// "All caught up". The pending set comes from `PendingQueueSelector`.
struct RightNowView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(NotificationActionRouter.self) private var actionRouter
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  @State private var pendingDoses: [PendingDose] = []

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RightNow")

  /// Re-keys the reload `.task` on anything that changes the pending set: which
  /// meds exist and each med's schedule. Keying on `medications.count` alone
  /// missed a same-count edit (e.g. moving a dose from 8:00 to 9:00).
  private var scheduleSignature: Int {
    var hasher = Hasher()
    for med in medications {
      hasher.combine(med.id)
      for dose in med.schedule {
        hasher.combine(dose.hour)
        hasher.combine(dose.minute)
        hasher.combine(dose.daysOfWeek)
        hasher.combine(dose.quantity)
      }
    }
    return hasher.finalize()
  }

  var body: some View {
    @Bindable var actionRouter = actionRouter
    // Glass is applied per visible leaf screen (the empty state here, and the
    // tap-through / success screens own theirs) rather than once on the nav, so
    // the layers never stack glass-on-glass.
    NavigationStack {
      content
        .navigationTitle("Right Now")
    }
    .task(id: scheduleSignature) { reload() }
    // The window is time-relative, so re-evaluate when the app is foregrounded
    // (time has passed since the last reload even if no data changed).
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { reload() }
    }
    // Presented when the "Snooze until…" notification action routes a dose here.
    .sheet(item: $actionRouter.pendingSnooze) { context in
      SnoozeView(context: context)
    }
  }

  private var content: some View {
    Group {
      if pendingDoses.isEmpty {
        AllCaughtUpView()
      } else {
        TapThroughQueueView(pendingDoses: pendingDoses, onFinished: reload)
          // Always-reachable affordances so PRN/OTC and anytime-log are never
          // gated behind the queue (SPEC §2.3 / issue #200). Scoped to the
          // queue state only: the caught-up state already surfaces both
          // destinations as in-content buttons, and adding top-bar items there
          // forced the root title to center under the system clock (#276).
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              NavigationLink {
                LogAnytimeView()
              } label: {
                Image(systemName: "calendar.badge.clock")
                  .accessibilityLabel("Log a scheduled dose anytime")
              }
            }
            ToolbarItem(placement: .topBarTrailing) {
              NavigationLink {
                PRNListView()
              } label: {
                Image(systemName: "pills")
                  .accessibilityLabel("Take as-needed")
              }
            }
          }
      }
    }
    // Transition between "doses pending" and "all caught up" is calm —
    // the user is leaving a working state, not celebrating completion
    // (`QueueSuccessView` owns the celebration with `Motion.dramatic`).
    // SwiftUI does not auto-skip custom `Animation` values under
    // reduce-motion; gate explicitly.
    .animation(reduceMotion ? nil : LiquidGlassTheme.Motion.gentle, value: pendingDoses.isEmpty)
  }

  private func reload() {
    do {
      pendingDoses = try PendingQueueSelector().pendingDoses(at: .now, in: modelContext)
    } catch {
      RightNowView.logger.error("Failed to compute pending doses: \(error.localizedDescription, privacy: .public)")
      pendingDoses = []
    }
  }
}

/// "All caught up" empty state, extracted so the parent's transition
/// observes a single view value rather than juggling the inner VStack.
private struct AllCaughtUpView: View {
  var body: some View {
    // Scrolls rather than clips: hero + two full-width buttons exceed the
    // height on smaller faces, which pushed the glyph up under the clock and
    // cut the second button off the bottom (#276). Matches the `ScrollView`
    // convention used by `SafetyWarningView`.
    ScrollView {
      VStack(spacing: LiquidGlassTheme.Spacing.standard) {
        VStack(spacing: LiquidGlassTheme.Spacing.compact) {
          Image(systemName: "checkmark.circle")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          LiquidGlassTheme.Typography.display("All caught up")
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .foregroundStyle(LiquidGlassTheme.Colors.primaryText)
        }

        // PRN is reached from the root, not the maintenance queue (SPEC §2.3).
        NavigationLink {
          PRNListView()
        } label: {
          Label("Take as-needed", systemImage: "pills")
        }
        // Same path as the queue-state toolbar item, surfaced as a large
        // empty-state affordance for discoverability when nothing is queued.
        NavigationLink {
          LogAnytimeView()
        } label: {
          Label("Log a scheduled dose", systemImage: "calendar.badge.clock")
        }
      }
      .frame(maxWidth: .infinity)
      .padding()
    }
    .glassBackground()
  }
}

#Preview {
  RightNowView()
    .environment(NotificationActionRouter.shared)
    .modelContainer(for: Medication.self, inMemory: true)
}
