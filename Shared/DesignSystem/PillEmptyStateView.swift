import SwiftUI

/// House `ContentUnavailableView` shape — 44 pt thin SF Symbol hero,
/// `displayFont` title, `footnoteFont` body. Used wherever a surface needs
/// an empty/inert state and we want all three to feel like the same product.
///
/// The host typically wraps this in `.overlay { … }` on the surface that
/// would otherwise be empty so it centres correctly rather than collapsing
/// into a `List` row.
struct PillEmptyStateView: View {
  let title: String
  let systemImage: String
  let description: String

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
    systemImage: "tray",
    description: "Log doses on your watch and they'll appear here."
  )
}
