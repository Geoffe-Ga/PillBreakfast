import SwiftUI
import WidgetKit

/// Smart Stack widget — surfaces the upcoming dose group ~15 min before it's due
/// (relevance set by `SmartStackTimelineProvider`). Tapping opens the watch app;
/// the single-tap `Button(intent:)` log arrives in #51.
struct SmartStackWidget: Widget {
  let kind = "SmartStackWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SmartStackTimelineProvider()) { entry in
      SmartStackWidgetView(entry: entry)
        .widgetURL(URL(string: "pillbreakfast://tap-through"))
    }
    .configurationDisplayName("Next Doses")
    .description("Your next scheduled doses, ready before they're due.")
    .supportedFamilies([.accessoryRectangular])
  }
}

#Preview(as: .accessoryRectangular) {
  SmartStackWidget()
} timeline: {
  SmartStackEntry(
    date: .now,
    doseGroup: SmartStackPlan.DoseGroupSummary(
      groupName: "Morning",
      doseCount: 3,
      scheduledAt: .now,
      containsHighRisk: false
    ),
    relevanceScore: 10,
    relevanceDuration: 900
  )
  SmartStackEntry.idle(at: .now)
}
