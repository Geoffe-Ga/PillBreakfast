import SwiftUI
import WidgetKit

/// Stub circular complication for Phase 7 (#48). Renders `"--"` centred on the
/// accessory background; tapping deep-links into the watch app's tap-through
/// queue (the `onOpenURL` handler is wired in #49).
struct PendingDoseComplication: Widget {
  let kind = "PendingDoseComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PendingDoseTimelineProvider()) { entry in
      PendingDoseComplicationView(entry: entry)
        .widgetURL(URL(string: "pillbreakfast://tap-through"))
    }
    .configurationDisplayName("Pending Doses")
    .description("Shows how many doses are due now.")
    .supportedFamilies([.accessoryCircular])
  }
}

struct PendingDoseComplicationView: View {
  let entry: PendingDoseEntry

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Text(entry.displayText)
        .font(.title2)
        .minimumScaleFactor(0.5)
    }
    .containerBackground(.clear, for: .widget)
  }
}
