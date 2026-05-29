import os
import SwiftData
import SwiftUI

/// Picks how many units of a PRN product to log, then writes the dose. Quantities
/// come from `prnAvailableQuantities`; if that's empty the user picks a freeform
/// count (with a warning that the product isn't configured). High-risk PRN meds
/// confirm with the EPIC 04 press-and-hold; everything else is a single tap.
///
/// This issue logs without the soft-warning interstitial — EPIC_05_ISSUE_05 wires
/// `SafetyEvaluator` in ahead of the write.
struct PRNQuantityPickerView: View {
  let medication: Medication
  let onLogged: () -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var quantity: Int
  @State private var writeFailed = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "PRNLogging")

  init(medication: Medication, onLogged: @escaping () -> Void) {
    self.medication = medication
    self.onLogged = onLogged
    _quantity = State(initialValue: medication.prnAvailableQuantities.first ?? 1)
  }

  var body: some View {
    VStack(spacing: LiquidGlassTheme.Spacing.standard) {
      LiquidGlassTheme.Typography.medicationName(medication.displayName)
        .multilineTextAlignment(.center)

      if medication.prnAvailableQuantities.isEmpty {
        // Not configured with preset quantities — let the user pick, but flag it.
        Stepper("Take \(quantity)", value: $quantity, in: 1 ... 20)
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
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Something went wrong saving this dose. Try again.")
    }
  }

  @ViewBuilder
  private var confirmButton: some View {
    if medication.isHighRisk {
      HighRiskConfirmButton(onConfirmed: log)
    } else {
      SingleTapConfirmButton(onConfirmed: log)
    }
  }

  private func log() {
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
      onLogged()
    } catch {
      PRNQuantityPickerView.logger.error("Failed to log PRN dose: \(error.localizedDescription, privacy: .public)")
      writeFailed = true
    }
  }
}
