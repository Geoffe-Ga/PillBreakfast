import SwiftUI

/// A brief glass-refraction sweep used on the confirm-and-advance success state
/// (SPEC §9: "confirm-and-advance uses a glass-shimmer + slide"). A diagonal
/// highlight band passes across the content once on appear, masked to the
/// content's shape so the shimmer reads as light moving through glass.
public struct ShimmerModifier: ViewModifier {
  @State private var phase: Double = 0

  public init() {}

  public func body(content: Content) -> some View {
    content
      .overlay(
        LinearGradient(
          colors: [.clear, .white.opacity(0.35), .clear],
          startPoint: .leading,
          endPoint: .trailing
        )
        .rotationEffect(.degrees(20))
        .offset(x: phase * 220 - 110)
        .blendMode(.plusLighter)
        .mask(content)
        .allowsHitTesting(false)
      )
      .onAppear {
        withAnimation(.linear(duration: 0.9)) { phase = 1 }
      }
  }
}

public extension View {
  /// Sweeps a one-shot glass shimmer across the view on appear.
  func shimmer() -> some View {
    modifier(ShimmerModifier())
  }
}
