import SwiftUI

public extension View {
  /// Applies PillBreakfast's Liquid Glass surface treatment (SPEC §9): a
  /// translucent, refractive background rather than a solid fill.
  ///
  /// No `#available` version branch: the deployment floor is watchOS 26 / iOS 26
  /// (Liquid Glass is the whole design language and the HealthKit Medications
  /// requirement already pins us to 26 — see CLAUDE.md), so `glassEffect()` is
  /// unconditionally available. An `if #available(watchOS 26.0, *)` guard here
  /// would be an always-true check the compiler flags, with a dead `else` for an
  /// OS we never deploy to. If the floor ever drops below 26, reintroduce a
  /// `.background(.ultraThinMaterial)` fallback in the `else`. Review: 2026-11-01.
  func glassBackground() -> some View {
    background {
      Rectangle()
        .fill(.clear)
        .glassEffect()
        .ignoresSafeArea()
    }
  }
}
