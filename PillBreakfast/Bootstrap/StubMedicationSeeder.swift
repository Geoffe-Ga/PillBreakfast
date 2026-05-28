import Foundation
import SwiftData

/// iPhone-only first-launch stub: seeds one high-risk medication so EPIC 02's
/// closing gate (edit on iPhone → propagate to watch) has something to push.
/// The watch never seeds this — it receives it via WCSession sync. Replaced by
/// the real Regimen tab UI in EPIC 03.
@MainActor
enum StubMedicationSeeder {
  /// Fixed IDs (all-0x11 / all-0x22 bytes) so re-seeds and cross-device graphs
  /// stay stable; built from raw bytes to avoid a force-unwrapped UUID string.
  static let stubMedicationID = UUID(
    uuid: (0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11)
  )
  static let lithiumIngredientID = UUID(
    uuid: (0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22)
  )

  static func seedIfNeeded(context: ModelContext) throws {
    let existing = try context.fetch(
      FetchDescriptor<Medication>(predicate: #Predicate { $0.id == stubMedicationID })
    )
    guard existing.isEmpty else { return }

    // Lithium is not in the OTC library (EPIC_02_ISSUE_03); seed it here so the
    // stub exercises the high-risk press-and-hold path in later epics.
    let lithium = Ingredient(
      id: lithiumIngredientID,
      name: "Lithium Carbonate",
      aliases: [],
      isHighRisk: true,
      dailyCeilingMg: 2400,
      minIntervalMinutes: 360
    )
    context.insert(lithium)

    let medication = Medication(
      id: stubMedicationID,
      displayName: "Stub Lithium 300mg",
      unitForm: .tablet,
      kind: .maintenance
    )
    medication.components = [MedicationComponent(ingredient: lithium, dosagePerUnitMg: 300)]
    medication.schedule = [ScheduledDose(hour: 8, minute: 0, quantity: 1)]
    context.insert(medication)

    try context.save()
  }
}
