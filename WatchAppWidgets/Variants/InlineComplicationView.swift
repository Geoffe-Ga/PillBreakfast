import SwiftUI
import WidgetKit

/// Inline accessory complication: one line — "N pending", "All clear", or a
/// neutral "Pills" when the count is unknown (the error/stub fallback).
struct InlineComplicationView: View {
  let entry: PendingDoseEntry

  var body: some View {
    switch entry.pendingCount {
    case let .some(count) where count > 0:
      Label("\(count) pending", systemImage: "pills.fill")
    case .some:
      Label("All clear", systemImage: "checkmark")
    case .none:
      Label("Pills", systemImage: "pills")
    }
  }
}
