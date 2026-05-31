import SwiftUI

/// Hosts the Regimen tab: the read-only regimen list under a navigation title.
struct RegimenTabHostView: View {
  var body: some View {
    NavigationStack {
      RegimenListView()
        .navigationTitle("Regimen")
        // Large-title on the root list; push destinations override to
        // `.inline` to give content room.
        .toolbarTitleDisplayMode(.large)
    }
  }
}

#Preview {
  RegimenTabHostView()
}
