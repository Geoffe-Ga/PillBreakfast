import Foundation
import SwiftData

/// The outcome of checking a newly-added dose's time against the user's
/// existing Pill Meals (SPEC §8.3). A med-add path turns this into an inline
/// prompt: assign to the matching meal, pick among several, or create a new
/// meal at the dose's time.
///
/// Not `Sendable`: the `single` / `multiple` cases carry live `@Model`
/// references, so this is a UI-layer decision type produced and consumed on the
/// main actor. `propose(forDoseAt:in:)` is a pure function over its inputs.
public enum PillMealSuggestion: Hashable {
  /// No meals configured yet — the first-launch sheet (§8.1) is the entry
  /// point, so no inline prompt fires.
  case none
  /// Exactly one existing meal is within the window — offer Add / Not now.
  case single(PillMeal)
  /// Several meals are within the window — offer a quick picker.
  case multiple([PillMeal])
  /// Meals exist but none is close — offer "Create new Pill Meal at HH:MM".
  case createNew(hour: Int, minute: Int)

  /// Closed (inclusive) match window: a meal "fits" a dose when their
  /// wall-clock times are ≤ 30 min apart. Matches the onboarding clustering
  /// tolerance.
  public static let windowMinutes = 30

  private static let minutesPerDay = 24 * 60

  /// Classifies a dose at `time` against `meals`. Pure — no fetch, no persist.
  /// The time distance wraps around midnight, so a 00:05 dose matches a 23:50
  /// meal (15 min apart, not 1425).
  public static func propose(
    forDoseAt time: (hour: Int, minute: Int),
    in meals: [PillMeal]
  ) -> PillMealSuggestion {
    guard !meals.isEmpty else { return .none }
    let doseMinutes = time.hour * 60 + time.minute
    let matches = meals.filter { meal in
      let rawDiff = abs((meal.targetHour * 60 + meal.targetMinute) - doseMinutes)
      let wrappedDiff = min(rawDiff, minutesPerDay - rawDiff)
      return wrappedDiff <= windowMinutes
    }
    switch matches.count {
    case 0: return .createNew(hour: time.hour, minute: time.minute)
    case 1: return .single(matches[0])
    default: return .multiple(matches)
    }
  }

  /// Localized wall-clock label ("9:30 AM") for an hour:minute pair. Shared by
  /// the add-path prompt and the HealthKit assignment sheet so the format
  /// doesn't drift between them.
  public static func timeLabel(hour: Int, minute: Int) -> String {
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: Date())
    let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight) ?? midnight
    return date.formatted(date: .omitted, time: .shortened)
  }
}

/// Materialises meal assignments for medications that arrive without a schedule
/// — the HealthKit import case (SPEC §8.4). Imported meds have no
/// `ScheduledDose`s, so "assign this med to Pill Breakfast" means *synthesise* a
/// dose at the meal's target time and bind it to the meal in one step.
public enum PillMealAssignment {
  /// For each selection with a non-nil meal, creates a `ScheduledDose` at the
  /// meal's target time bound to that meal, then saves once. Selections with a
  /// `nil` meal (the "None" picker option) are skipped. Returns the number of
  /// doses created. Throws on save failure; the caller rolls back.
  @MainActor
  @discardableResult
  public static func assignImported(
    _ selections: [(medication: Medication, meal: PillMeal?)],
    quantity: Int = 1,
    in context: ModelContext
  ) throws -> Int {
    var created = 0
    for selection in selections {
      guard let meal = selection.meal else { continue }
      let dose = ScheduledDose(
        hour: meal.targetHour,
        minute: meal.targetMinute,
        quantity: quantity,
        medication: selection.medication,
        pillMeal: meal
      )
      context.insert(dose)
      created += 1
    }
    if created > 0 { try context.save() }
    return created
  }
}
