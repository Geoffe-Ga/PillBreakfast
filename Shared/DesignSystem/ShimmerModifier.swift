import SwiftUI

/// A brief glass-refraction sweep used on the confirm-and-advance success state
/// (SPEC §9: "confirm-and-advance uses a glass-shimmer + slide"). A diagonal
/// highlight band passes across the content once on appear, masked to the
/// content's shape so the shimmer reads as light moving through glass.
public struct ShimmerModifier: ViewModifier {
  /// Width of the moving highlight band. The sweep distance is derived from the
  /// measured content width (below), so this is the only fixed dimension.
  private static let bandWidth: CGFloat = 80

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var phase: Double = 0

  public init() {}

  public func body(content: Content) -> some View {
    content
      .overlay {
        GeometryReader { proxy in
          LinearGradient(
            colors: [.clear, .white.opacity(0.35), .clear],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: Self.bandWidth)
          .rotationEffect(.degrees(20))
          // Sweep from fully off the leading edge to fully off the trailing edge,
          // scaled to the actual rendered width so it works at any Dynamic Type size.
          .offset(x: phase * (proxy.size.width + Self.bandWidth) - Self.bandWidth)
          .blendMode(.plusLighter)
          .mask(content)
          .allowsHitTesting(false)
        }
      }
      .onAppear {
        // Respect Reduce Motion: skip the sweep entirely (band stays off-screen),
        // so the label simply renders without animation.
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.9)) { phase = 1 }
      }
  }
}

public extension View {
  /// Sweeps a one-shot glass shimmer across the view on appear (no-op under
  /// Reduce Motion).
  func shimmer() -> some View {
    modifier(ShimmerModifier())
  }
}
