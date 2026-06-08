import SwiftUI
import WidgetKit

/// Entry point for the watchOS widget extension: the pending-dose complication
/// (circular/corner/inline, #49) and the Smart Stack widget (#50).
@main
struct WatchAppWidgetsBundle: WidgetBundle {
  var body: some Widget {
    PendingDoseComplication()
    SmartStackWidget()
  }
}
