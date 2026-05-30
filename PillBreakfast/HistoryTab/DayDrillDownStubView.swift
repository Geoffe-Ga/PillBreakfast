import SwiftUI

/// Stub drill-down for a heatmap day. Prints "Selected: <date>" — the real
/// per-day dose breakdown lands in a follow-up.
struct DayDrillDownStubView: View {
  let date: Date

  var body: some View {
    Text("Selected: \(date.formatted(date: .abbreviated, time: .omitted))")
      .foregroundStyle(.secondary)
      .navigationTitle("Day")
      .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    DayDrillDownStubView(date: .now)
  }
}
