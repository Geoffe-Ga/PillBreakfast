import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Single-tap "log this dose" from the Smart Stack widget. A thin wrapper over
/// `LogNextDoseService` (which holds the safety logic). It never one-tap-logs a
/// high-risk med — the service throws `highRiskForbidden` (defense-in-depth; the
/// widget hides the button for high-risk groups, #220). Lives in the widget
/// target only, not iOS.
struct LogNextDoseIntent: AppIntent {
  static let title: LocalizedStringResource = "Log Next Dose"

  @Parameter(title: "Medication ID") var medicationID: String
  @Parameter(title: "Scheduled For") var scheduledFor: Date
  @Parameter(title: "Quantity") var quantity: Int
  @Parameter(title: "Medication Name") var medicationName: String

  init() {}

  init(medicationID: String, scheduledFor: Date, quantity: Int, medicationName: String) {
    self.medicationID = medicationID
    self.scheduledFor = scheduledFor
    self.quantity = quantity
    self.medicationName = medicationName
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let uuid = UUID(uuidString: medicationID) else {
      throw LogIntentError.invalidMedicationID
    }
    let spec = NextDoseSpec(
      medicationID: uuid,
      scheduledFor: scheduledFor,
      quantity: quantity,
      medicationName: medicationName
    )
    try LogNextDoseService.log(spec, in: makeContext())
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }

  /// Read-write App Group container (the log writes). A fresh container per call
  /// — widget extensions have no process-persistent container to reuse, so don't
  /// "optimize" this into a static. Never `PersistenceController.shared`.
  /// `@MainActor` because the App Group statics are isolated.
  @MainActor
  private func makeContext() throws -> ModelContext {
    let configuration = ModelConfiguration(url: PersistenceController.appGroupStoreURL)
    let container = try ModelContainer(for: PersistenceController.schema, configurations: configuration)
    return ModelContext(container)
  }
}
