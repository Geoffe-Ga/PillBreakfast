import os
import SwiftData
import SwiftUI

/// Confirm + write step for the Log tab. Mirrors the watch anytime-log contract:
/// runs `SafetyEvaluator`, writes via `DoseEventWriter` (`loggedOn: .iphone`),
/// then syncs to the watch via `DoseEventBatchTransfer`. High-risk meds require
/// an explicit confirmation tap — the watch's press-and-hold gesture has no
/// iPhone idiom, but the deliberate-action intent is preserved.
struct LogDoseConfirmView: View {
  let medication: Medication
  let onLogged: (String) -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var quantity: Int
  @State private var violations: [Violation] = []
  @State private var showingSafetyWarning = false
  @State private var showingHighRiskConfirm = false
  @State private var writeFailed = false
  /// Guards against a double-tap logging the same dose twice in this view's life.
  @State private var alreadyLogged = false

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "LogTab")

  init(medication: Medication, onLogged: @escaping (String) -> Void) {
    self.medication = medication
    self.onLogged = onLogged
    _quantity = State(initialValue: AnytimeLogQuantity.defaultQuantity(for: medication))
  }

  var body: some View {
    Form {
      Section {
        LiquidGlassTheme.Typography.display(medication.displayName)
        LiquidGlassTheme.Typography.footnote(LogDoseDetail.summary(for: medication, quantity: quantity))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
      Section {
        Stepper(value: $quantity, in: 1 ... 20) {
          HStack {
            Text("Quantity")
            Spacer()
            Text("\(quantity)").monospacedDigit()
          }
        }
      }
      Section {
        Button {
          attemptLog()
        } label: {
          Text(medication.isHighRisk ? "Log high-risk dose" : "Log dose")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      }
    }
    .scrollContentBackground(.hidden)
    .glassBackground()
    .navigationTitle("Confirm")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Log \(medication.displayName) now?",
      isPresented: $showingHighRiskConfirm,
      titleVisibility: .visible
    ) {
      Button("Log dose", role: .destructive) { performLog() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This is a high-risk medication. Confirm you're logging it now.")
    }
    .alert("Check before logging", isPresented: $showingSafetyWarning) {
      Button("Log anyway", role: .destructive) { performLog() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(safetyWarningMessage)
    }
    .alert("Dose not recorded", isPresented: $writeFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Something went wrong saving this dose. Please try again.")
    }
  }

  private var safetyWarningMessage: String {
    violations
      .map { ViolationMessageBuilder.message(for: $0, at: .now) }
      .map { ([$0.title] + $0.detailLines).joined(separator: "\n") }
      .joined(separator: "\n\n")
  }

  /// Safety-gate the log: ceiling/interval violations show a soft warning the
  /// user can override; high-risk meds get an explicit confirm; otherwise log.
  private func attemptLog() {
    do {
      violations = try SafetyEvaluator.violationsIfTaken(medication, quantity: quantity, at: .now, in: modelContext)
    } catch {
      Self.logger.error("Safety check failed: \(error.localizedDescription, privacy: .public)")
      violations = []
    }
    if !violations.isEmpty {
      showingSafetyWarning = true
    } else if medication.isHighRisk {
      showingHighRiskConfirm = true
    } else {
      performLog()
    }
  }

  private func performLog() {
    guard !alreadyLogged else { return }
    alreadyLogged = true
    do {
      let event = try DoseEventWriter.writeDoseEvent(
        for: medication,
        scheduledFor: nil,
        quantity: quantity,
        status: .taken,
        loggedOn: .iphone,
        at: .now,
        in: modelContext
      )
      // Watch sync is non-fatal — the dose is already committed to this store
      // (which the History tab reads); the transfer just propagates it to the
      // wrist for running totals.
      do {
        try DoseEventBatchTransfer.transfer([event])
      } catch {
        Self.logger.error("Failed to queue dose transfer to watch: \(error.localizedDescription, privacy: .public)")
      }
      onLogged(medication.displayName)
    } catch {
      Self.logger.error("Failed to log dose: \(error.localizedDescription, privacy: .public)")
      alreadyLogged = false
      writeFailed = true
    }
  }
}

/// Shared "300mg · 1 tablet" subtitle builder for the Log tab rows and confirm
/// screen. Single-ingredient meds show mg; combos show just the count.
enum LogDoseDetail {
  static func summary(for medication: Medication, quantity: Int? = nil) -> String {
    let qty = quantity ?? AnytimeLogQuantity.defaultQuantity(for: medication)
    let unit = qty == 1 ? medication.unitForm.singularLabel : medication.unitForm.pluralLabel
    if medication.components.count == 1, let mgPerUnit = medication.components.first?.dosagePerUnitMg {
      return "\(Int(mgPerUnit.rounded()))mg · \(qty) \(unit)"
    }
    return "\(qty) \(unit)"
  }
}
