import SwiftUI

public extension View {
  /// Conditionally applies a transform, leaving the view untouched otherwise.
  ///
  /// Used for context-dependent chrome where the rest of the modifier chain must
  /// continue — e.g. a form that supplies its own `.glassBackground()` only when
  /// it isn't already inside a glass-providing sheet (issue #103).
  @ViewBuilder
  func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}
