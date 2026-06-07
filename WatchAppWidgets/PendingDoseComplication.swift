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

  /// `nil` (the stub) shows `"--"`; #49 renders the real count or `"✓"`.
  private var displayText: String {
    guard let count = entry.pendingCount else { return "--" }
    return count == 0 ? "✓" : String(count)
  }

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      Text(displayText)
        .font(.title2)
        .minimumScaleFactor(0.5)
    }
    .containerBackground(.clear, for: .widget)
  }
}
