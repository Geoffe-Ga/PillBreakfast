import SwiftUI
import WidgetKit

/// Circular accessory complication: the pending count (or `"✓"` / `"--"`) centred
/// on the accessory ring. No color — `widgetAccentable()` lets the watch face
/// tint it; amber stays reserved for the main-app press-and-hold (CLAUDE.md).
struct CircularComplicationView: View {
  let entry: PendingDoseEntry

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Text(entry.displayText)
        .font(.title2)
        .minimumScaleFactor(0.5)
    }
    .widgetAccentable()
  }
}
