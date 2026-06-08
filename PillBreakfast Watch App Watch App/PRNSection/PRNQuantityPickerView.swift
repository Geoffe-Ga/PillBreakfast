import os
import SwiftData
import SwiftUI
import WatchKit

/// Picks how many units of a PRN product to log, then logs the dose — gating the
/// write on `SafetyEvaluator`. If the dose would cross an ingredient ceiling or
/// minimum interval, it routes to the `SafetyWarningView` interstitial first
/// (SPEC §2.3); otherwise it writes directly. Quantities come from
/// `prnAvailableQuantities` (freeform + warning if unset). High-risk meds confirm
/// — and override — with the EPIC 04 press-and-hold; everything else single-taps.
struct PRNQuantityPickerView: View {
  let medication: Medication
  /// Called after a successful write so the host can refresh (e.g. reload totals).
  /// It must **not** navigate — this view owns its own dismissal via `dismiss()`,
  /// so a host that also popped would double-pop.
  let onLogged: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var quantity: Int
  /// Non-nil while the safety interstitial is showing for these violations.
  @State private var pendingViolations: [Violation]?
  @State private var writeFailed = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "PRNLogging")

  /// Watch-side stepper cap when no preset quantities are configured; wider than `PRNFormSection.quantityRange` (1...10) which is the *configuration* cap.
  private static let fallbackQuantityRange = 1 ... 20

  init(medication: Medication, onLogged: @escaping () -> Void) {
    self.medication = medication
    self.onLogged = onLogged
    _quantity = State(initialValue: medication.prnAvailableQuantities.first ?? 1)
  }

  var body: some View {
    Group {
      if let pendingViolations {
        SafetyWarningView(
          violations: pendingViolations,
          isHighRisk: medication.isHighRisk,
          onOverride: write,
          onCancel: { dismiss() } // back to the PRN list, no write
        )
      } else {
        picker
      }
    }
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Something went wrong saving this dose. Try again.")
    }
  }

  private var picker: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
        .multilineTextAlignment(.center)

      if medication.prnAvailableQuantities.isEmpty {
        // Not configured with preset quantities — let the user pick, but flag it.
        Stepper("Take \(quantity)", value: $quantity, in: Self.fallbackQuantityRange)
        LiquidGlassTheme.Typography.caption("No preset quantities — set them on the iPhone.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      } else {
        Picker("Quantity", selection: $quantity) {
          ForEach(medication.prnAvailableQuantities, id: \.self) { option in
            Text("Take \(option)").tag(option)
          }
        }
        .labelsHidden()
      }

      confirmButton
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground()
    .navigationTitle("As-Needed")
  }

  @ViewBuilder
  private var confirmButton: some View {
    if medication.isHighRisk {
      HighRiskConfirmButton(onConfirmed: attemptLog)
    } else {
      SingleTapConfirmButton(onConfirmed: attemptLog)
    }
  }

  /// Runs the safety check first: clean → write; violations → show the interstitial.
  private func attemptLog() {
    do {
      let violations = try SafetyEvaluator.violationsIfTaken(medication, quantity: quantity, at: .now, in: modelContext)
      if violations.isEmpty {
        write()
      } else {
        // Signal "something unusual" on the wrist as the warning appears, so the
        // user notices before reading.
        WKInterfaceDevice.current().play(.notification)
        pendingViolations = violations
      }
    } catch {
      PRNQuantityPickerView.logger.error("Safety check failed: \(error.localizedDescription, privacy: .public)")
      writeFailed = true
    }
  }

  /// Writes the dose (direct or after override) and returns to the list.
  private func write() {
    do {
      // PRN doses have no scheduled time. DoseEventWriter snapshots ingredientAmounts.
      let event = try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: nil,
        quantity: quantity,
        status: .taken,
        loggedOn: .watch,
        at: .now,
        in: modelContext
      )
      // Reverse-sync to the iPhone (queued; survives the phone asleep). A transfer
      // failure doesn't undo the local log — the watch store is authoritative.
      do {
        try DoseEventBatchTransfer.transfer([event])
      } catch {
        PRNQuantityPickerView.logger.error("Failed to queue PRN dose transfer: \(error.localizedDescription, privacy: .public)")
      }
      // Refresh the complication's pending count (debounced; see WidgetReloadCoordinator).
      Task { await WidgetReloadCoordinator.shared.scheduleReload() }
      onLogged()
      dismiss()
    } catch {
      // Keep the interstitial up (if it was showing) so an override that fails to
      // write keeps its context; the alert appears over it and the user can retry
      // or cancel from there.
      PRNQuantityPickerView.logger.error("Failed to log PRN dose: \(error.localizedDescription, privacy: .public)")
      writeFailed = true
    }
  }
}
