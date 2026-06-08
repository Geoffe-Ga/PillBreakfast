import SwiftUI
import WidgetKit

/// Pending-dose complication. One `Widget` serving three accessory families via
/// `ComplicationRouter` (a single watch-face picker entry). Tapping deep-links
/// into the watch app's tap-through queue via `pillbreakfast://tap-through`.
struct PendingDoseComplication: Widget {
  let kind = "PendingDoseComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PendingDoseTimelineProvider()) { entry in
      ComplicationRouter(entry: entry)
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "pillbreakfast://tap-through"))
    }
    .configurationDisplayName("Pending Doses")
    .description("Shows how many doses are due now.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
  }
}

/// Renders the family-appropriate view. Falls back to circular for any family
/// not in `supportedFamilies` (defensive; the registration limits what's shown).
private struct ComplicationRouter: View {
  @Environment(\.widgetFamily) private var family
  let entry: PendingDoseEntry

  var body: some View {
    switch family {
    case .accessoryCircular: CircularComplicationView(entry: entry)
    case .accessoryCorner: CornerComplicationView(entry: entry)
    case .accessoryInline: InlineComplicationView(entry: entry)
    default: CircularComplicationView(entry: entry)
    }
  }
}
