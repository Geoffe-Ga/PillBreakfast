import SwiftData
import SwiftUI

/// Renders the "Pill Meals" section on the Regimen tab. Empty state shows the
/// `PillEmptyStateView`; non-empty shows one row per meal (name + target time
/// + assigned-dose count) and a "New Pill Meal" affordance.
struct PillMealsListSection: View {
  let meals: [PillMeal]

  var body: some View {
    Section {
      if meals.isEmpty {
        PillEmptyStateView(
          title: "No pill meals yet",
          description: "Group meds you take together to get a single notification at that time.",
          systemImage: "fork.knife"
        )
        .frame(maxWidth: .infinity, minHeight: 140)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      } else {
        ForEach(meals) { meal in
          NavigationLink {
            PillMealEditorView(existing: meal)
          } label: {
            row(for: meal)
          }
        }
      }
      NavigationLink {
        PillMealEditorView()
      } label: {
        Label("New Pill Meal", systemImage: "plus.circle")
      }
    } header: {
      LiquidGlassTheme.Typography.headline("Pill Meals")
        .textCase(nil)
    }
  }

  private func row(for meal: PillMeal) -> some View {
    HStack(alignment: .center, spacing: LiquidGlassTheme.Spacing.compact) {
      VStack(alignment: .leading, spacing: 2) {
        LiquidGlassTheme.Typography.medicationName(meal.name)
        LiquidGlassTheme.Typography.footnote(Self.subtitle(for: meal))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  /// "9:30 AM · 5 doses" / "9:30 AM · 1 dose" / "9:30 AM · No doses".
  /// `internal static` so the wording can be unit-tested without a SwiftUI runtime.
  static func subtitle(for meal: PillMeal) -> String {
    let timeText = formattedTime(hour: meal.targetHour, minute: meal.targetMinute)
    let count = meal.scheduledDoses.count
    let doseText = count == 0 ? "No doses" : (count == 1 ? "1 dose" : "\(count) doses")
    return "\(timeText) · \(doseText)"
  }

  private static func formattedTime(hour: Int, minute: Int) -> String {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: Date())
    let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) ?? midnight
    return date.formatted(date: .omitted, time: .shortened)
  }
}
