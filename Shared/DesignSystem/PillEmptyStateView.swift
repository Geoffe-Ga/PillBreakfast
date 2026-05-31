import SwiftUI

/// House `ContentUnavailableView` shape — 44 pt thin SF Symbol + `displayFont`
/// title + `footnoteFont` body. Wrap in `.overlay { … }` so it centres
/// instead of collapsing into a `List` row.
struct PillEmptyStateView: View {
  let title: String
  let systemImage: String
  let description: String

  init(title: String, description: String, systemImage: String = "tray") {
    self.title = title
    self.description = description
    self.systemImage = systemImage
  }

  var body: some View {
    ContentUnavailableView {
      Label {
        // Display titles ("All caught up", "No history yet") are short
        // labels; scaling to 0.8 keeps them on one line at AX5 rather
        // than truncating with an ellipsis.
        LiquidGlassTheme.Typography.display(title)
          .minimumScaleFactor(0.8)
      } icon: {
        Image(systemName: systemImage)
          .font(.system(size: 44, weight: .light))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
    } description: {
      LiquidGlassTheme.Typography.footnote(description)
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        .multilineTextAlignment(.center)
    }
  }
}

#Preview {
  PillEmptyStateView(
    title: "No history yet",
    description: "Log doses on your watch and they'll appear here."
  )
}
