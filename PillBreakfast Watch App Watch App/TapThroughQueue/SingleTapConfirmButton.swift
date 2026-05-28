import SwiftUI

/// Single-tap "Mark Taken" for non-high-risk meds (the EPIC 03 behaviour,
/// extracted so `MarkTakenView` can compose either this or the press-and-hold
/// control). A single tap is fine for vitamins; high-risk meds use
/// `HighRiskConfirmButton` instead.
struct SingleTapConfirmButton: View {
  let onConfirmed: () -> Void

  var body: some View {
    Button("Mark Taken", action: onConfirmed)
      .buttonStyle(.borderedProminent)
  }
}
