import SwiftUI

struct RootView: View {
  var body: some View {
    VStack {
      Text("Hello PillBreakfast")
        .font(.title3)
      Text("Watch app · placeholder")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("WC state: \(WatchConnectivityCoordinator.shared.activationState.displayName)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

#Preview {
  RootView()
}
