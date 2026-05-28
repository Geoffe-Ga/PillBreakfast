import SwiftUI

/// One pill per screen. Single-tap confirm for now; the press-and-hold path for
/// high-risk meds and the actual DoseEvent write land in EPIC_03_ISSUE_03.
struct MarkTakenView: View {
  let medicationName: String

  var body: some View {
    VStack(spacing: 12) {
      Text(medicationName)
        .font(.headline)
        .multilineTextAlignment(.center)

      Button("Mark Taken") {
        // Stub: logging a DoseEvent lands in EPIC_03_ISSUE_03.
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }
}

#Preview {
  MarkTakenView(medicationName: "Stub Lithium 300mg")
}
