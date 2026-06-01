import SwiftData
import SwiftUI

/// First-launch "we found N pill groups in your regimen" stub sheet (SPEC §8.1).
/// Skeleton scope: renders the proposed clusters as a read-only list and flips
/// `UserPreferences.pillMealsOnboarded` to `true` on Done so the sheet never
/// fires again. Real per-row save / skip and PillMeal persistence land in
/// the next issue.
struct PillMealOnboardingSheet: View {
  let suggestions: [SuggestedMeal]
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(suggestions) { suggestion in
            row(for: suggestion)
          }
        } header: {
          LiquidGlassTheme.Typography.headline("Suggested Pill Meals")
            .textCase(nil)
        } footer: {
          LiquidGlassTheme.Typography.footnote("Naming and saving lands in the next update — for now this just shows what we found.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
        }
      }
      .scrollContentBackground(.hidden)
      .glassBackground()
      .navigationTitle("Pill Meals")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: onDismiss)
        }
      }
    }
  }

  private func row(for suggestion: SuggestedMeal) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      LiquidGlassTheme.Typography.medicationName(suggestion.suggestedName)
      LiquidGlassTheme.Typography.footnote("\(Self.timeLabel(hour: suggestion.hour, minute: suggestion.minute)) · \(suggestion.doseIDs.count) doses")
        .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  /// "9:30 AM" via the system formatter; locale-respecting.
  static func timeLabel(hour: Int, minute: Int) -> String {
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: Date())
    let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) ?? midnight
    return date.formatted(date: .omitted, time: .shortened)
  }
}

#Preview {
  PillMealOnboardingSheet(
    suggestions: [
      SuggestedMeal(suggestedName: "Pill Breakfast", hour: 9, minute: 30, doseIDs: [UUID(), UUID()]),
      SuggestedMeal(suggestedName: "Pill Dinner", hour: 21, minute: 0, doseIDs: [UUID(), UUID(), UUID()]),
    ],
    onDismiss: {}
  )
}
