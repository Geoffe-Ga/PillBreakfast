import SwiftUI

struct RootView: View {
  var body: some View {
    VStack {
      Text("Hello PillBreakfast")
        .font(.title)
      Text("iPhone companion · placeholder")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

#Preview {
  RootView()
}
