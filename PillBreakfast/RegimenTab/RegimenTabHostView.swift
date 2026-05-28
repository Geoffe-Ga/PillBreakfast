import SwiftUI

/// Hosts the Regimen tab: the read-only regimen list under a navigation title.
struct RegimenTabHostView: View {
  var body: some View {
    NavigationStack {
      RegimenListView()
        .navigationTitle("Regimen")
    }
  }
}

#Preview {
  RegimenTabHostView()
}
