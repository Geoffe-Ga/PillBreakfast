import SwiftUI
import WidgetKit

/// Corner accessory complication: a pill / checkmark glyph with a short curved
/// `.widgetLabel` — the count when doses are pending, "Clear" when caught up.
struct CornerComplicationView: View {
  let entry: PendingDoseEntry

  var body: some View {
    Image(systemName: entry.hasPending ? "pills.fill" : "checkmark")
      .widgetAccentable()
      .widgetLabel(entry.hasPending ? entry.displayText : "Clear")
  }
}
