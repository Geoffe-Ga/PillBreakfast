import SwiftUI

/// Single-tap "Mark Taken" for non-high-risk meds (the EPIC 03 behaviour,
/// extracted so `MarkTakenView` can compose either this or the press-and-hold
/// control). A single tap is fine for vitamins; high-risk meds use
/// `HighRiskConfirmButton` instead.
///
/// Uses `.borderedProminent` rather than a hand-rolled `ButtonStyle` so the
/// foreground/background contrast tracks the system tint resolution (an
/// accessibility-inverted or high-contrast environment gets the right
/// foreground without us hardcoding `.white`). The bordered-prominent style
/// already animates its press feedback with a snappy system spring —
/// re-implementing it with a custom `scaleEffect` would risk gesture conflicts
/// with watchOS's digital-crown scroll without buying meaningfully more
/// motion than the system already provides.
struct SingleTapConfirmButton: View {
  let onConfirmed: () -> Void

  var body: some View {
    Button("Mark Taken", action: onConfirmed)
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
  }
}
