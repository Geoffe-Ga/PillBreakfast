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
        LiquidGlassTheme.Typography.display(title)
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
