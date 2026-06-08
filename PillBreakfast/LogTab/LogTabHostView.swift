import SwiftUI

/// iPhone **Log** tab — a manual, user-initiated dose log.
///
/// This is the *only* place the iPhone writes a `DoseEvent`. It is deliberately
/// not a "take pills now" prompt (the watch still owns scheduled prompting and
/// the tap-through ritual); it is a pull-based convenience for recording a dose
/// from the phone when the watch isn't handy. Every write goes through the same
/// `DoseEventWriter` + `SafetyEvaluator` path the watch uses and syncs to the
/// watch via `DoseEventBatchTransfer`, so the two surfaces never diverge. See
/// SPEC §6.4.
struct LogTabHostView: View {
  @State private var showingPicker = false
  @State private var loggedMedicationName: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: LiquidGlassTheme.Spacing.generous) {
        Spacer()
        Image(systemName: "pills.circle.fill")
          .font(.system(size: 64, weight: .light))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        LiquidGlassTheme.Typography.footnote("Record a medication you've just taken.")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          .multilineTextAlignment(.center)
        Button {
          showingPicker = true
        } label: {
          Text("Log a dose").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        Spacer()
      }
      .padding()
      .glassBackground()
      .navigationTitle("Log")
      .sheet(isPresented: $showingPicker) {
        LogMedicationPickerView { name in loggedMedicationName = name }
      }
      .alert(
        "Dose logged",
        isPresented: Binding(
          get: { loggedMedicationName != nil },
          set: { if !$0 { loggedMedicationName = nil } }
        )
      ) {
        Button("OK", role: .cancel) { loggedMedicationName = nil }
      } message: {
        Text(loggedMedicationName.map { "\($0) recorded." } ?? "")
      }
    }
  }
}
