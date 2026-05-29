import SwiftUI

/// PRN configuration fields for the medication form, shown when `kind == .prn`.
/// This is the EPIC 05 skeleton: it ships the "available quantities" editor and a
/// components placeholder, but the form's PRN save semantics (persisting the
/// quantities and multi-ingredient components) land in EPIC_05_ISSUE_06.
///
/// This is *configuration*, never dose logging — the iPhone never logs doses.
struct PRNFormSection: View {
  @Bindable var formState: MedicationFormState
  @State private var newQuantity = 1

  var body: some View {
    Section {
      ForEach(formState.prnAvailableQuantities, id: \.self) { quantity in
        Text("Take \(quantity)")
      }
      .onDelete { formState.prnAvailableQuantities.remove(atOffsets: $0) }

      HStack {
        Stepper("Quantity: \(newQuantity)", value: $newQuantity, in: 1 ... 10)
        Button("Add") {
          if !formState.prnAvailableQuantities.contains(newQuantity) {
            formState.prnAvailableQuantities.append(newQuantity)
            formState.prnAvailableQuantities.sort()
          }
        }
      }
    } header: {
      Text("Available quantities")
    } footer: {
      Text("How many units the user can log at once (e.g. 1 or 2 tablets).")
    }

    Section {
      Button("Add ingredient") {}
        // Multi-ingredient combo editing is wired up in a later phase.
        .disabled(true)
    } header: {
      Text("Components")
    } footer: {
      Text("Combo (multi-ingredient) PRN products are configured here in a later phase.")
    }
  }
}
