import SwiftUI
import WidgetKit

/// Entry point for the watchOS widget extension.
///
/// Phase 7 skeleton (#48): a single stub circular complication. Later issues
/// add the other complication families (#49) and the Smart Stack widget (#50)
/// to this bundle.
@main
struct WatchAppWidgetsBundle: WidgetBundle {
  var body: some Widget {
    PendingDoseComplication()
  }
}
