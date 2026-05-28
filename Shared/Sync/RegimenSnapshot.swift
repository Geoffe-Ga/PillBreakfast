import Foundation
import SwiftData

// One-way (iPhone → watch) value-type mirror of the regimen graph.
//
// SwiftData @Model classes are reference types with relationship semantics that
// do not round-trip through JSONEncoder and are not Sendable, so they must never
// cross the WCSession / actor boundary directly. RegimenSnapshot is the immutable
// wire format. DoseEvents flow back watch → iPhone over a separate channel (EPIC 03).

public struct RegimenSnapshot: Codable, Sendable, Hashable {
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  public var ingredients: [IngredientDTO]
  public var medications: [MedicationDTO]

  public init(
    schemaVersion: Int = RegimenSnapshot.currentSchemaVersion,
    ingredients: [IngredientDTO],
    medications: [MedicationDTO]
  ) {
    self.schemaVersion = schemaVersion
    self.ingredients = ingredients
    self.medications = medications
  }
}

public struct IngredientDTO: Codable, Sendable, Hashable {
  public let id: UUID
  public let name: String
  public let aliases: [String]
  public let isHighRisk: Bool
  public let dailyCeilingMg: Double?
  public let minIntervalMinutes: Int?

  public init(
    id: UUID,
    name: String,
    aliases: [String],
    isHighRisk: Bool,
    dailyCeilingMg: Double?,
    minIntervalMinutes: Int?
  ) {
    self.id = id
    self.name = name
    self.aliases = aliases
    self.isHighRisk = isHighRisk
    self.dailyCeilingMg = dailyCeilingMg
    self.minIntervalMinutes = minIntervalMinutes
  }
}

public struct ComponentDTO: Codable, Sendable, Hashable {
  public let id: UUID
  public let ingredientID: UUID? // references an IngredientDTO in the snapshot
  public let dosagePerUnitMg: Double

  public init(id: UUID, ingredientID: UUID?, dosagePerUnitMg: Double) {
    self.id = id
    self.ingredientID = ingredientID
    self.dosagePerUnitMg = dosagePerUnitMg
  }
}

public struct ScheduledDoseDTO: Codable, Sendable, Hashable {
  public let id: UUID
  public let hour: Int
  public let minute: Int
  public let quantity: Int
  public let daysOfWeek: [Int]

  public init(id: UUID, hour: Int, minute: Int, quantity: Int, daysOfWeek: [Int]) {
    self.id = id
    self.hour = hour
    self.minute = minute
    self.quantity = quantity
    self.daysOfWeek = daysOfWeek
  }
}

public struct MedicationDTO: Codable, Sendable, Hashable {
  public let id: UUID
  public let displayName: String
  public let fullName: String?
  public let unitForm: MedicationForm
  public let kind: MedicationKind
  public let colorHex: String?
  public let notes: String?
  public let isArchived: Bool
  public let createdAt: Date
  public let healthKitConceptID: String?
  public let prnAvailableQuantities: [Int]
  public let components: [ComponentDTO]
  public let schedule: [ScheduledDoseDTO]

  public init(
    id: UUID,
    displayName: String,
    fullName: String?,
    unitForm: MedicationForm,
    kind: MedicationKind,
    colorHex: String?,
    notes: String?,
    isArchived: Bool,
    createdAt: Date,
    healthKitConceptID: String?,
    prnAvailableQuantities: [Int],
    components: [ComponentDTO],
    schedule: [ScheduledDoseDTO]
  ) {
    self.id = id
    self.displayName = displayName
    self.fullName = fullName
    self.unitForm = unitForm
    self.kind = kind
    self.colorHex = colorHex
    self.notes = notes
    self.isArchived = isArchived
    self.createdAt = createdAt
    self.healthKitConceptID = healthKitConceptID
    self.prnAvailableQuantities = prnAvailableQuantities
    self.components = components
    self.schedule = schedule
  }
}

public extension RegimenSnapshot {
  /// Reads the current SwiftData store into an immutable snapshot. Main-actor-bound
  /// because it touches `@Model` objects, but returns only Sendable value types.
  @MainActor
  static func from(context: ModelContext) throws -> RegimenSnapshot {
    let ingredients = try context.fetch(FetchDescriptor<Ingredient>()).map { ingredient in
      IngredientDTO(
        id: ingredient.id,
        name: ingredient.name,
        aliases: ingredient.aliases,
        isHighRisk: ingredient.isHighRisk,
        dailyCeilingMg: ingredient.dailyCeilingMg,
        minIntervalMinutes: ingredient.minIntervalMinutes
      )
    }

    let medications = try context.fetch(FetchDescriptor<Medication>()).map { medication in
      MedicationDTO(
        id: medication.id,
        displayName: medication.displayName,
        fullName: medication.fullName,
        unitForm: medication.unitForm,
        kind: medication.kind,
        colorHex: medication.colorHex,
        notes: medication.notes,
        isArchived: medication.isArchived,
        createdAt: medication.createdAt,
        healthKitConceptID: medication.healthKitConceptID,
        prnAvailableQuantities: medication.prnAvailableQuantities,
        components: medication.components.map {
          ComponentDTO(id: $0.id, ingredientID: $0.ingredient?.id, dosagePerUnitMg: $0.dosagePerUnitMg)
        },
        schedule: medication.schedule.map {
          ScheduledDoseDTO(id: $0.id, hour: $0.hour, minute: $0.minute, quantity: $0.quantity, daysOfWeek: $0.daysOfWeek)
        }
      )
    }

    return RegimenSnapshot(ingredients: ingredients, medications: medications)
  }

  /// Writes the snapshot into a target store with upsert-by-`id` semantics.
  /// Medications present in the store but absent from the snapshot are archived
  /// (`isArchived = true`), never deleted, so a partial/garbled push can't destroy history.
  @MainActor
  func apply(to context: ModelContext) throws {
    var ingredientByID = try Dictionary(
      context.fetch(FetchDescriptor<Ingredient>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    for dto in ingredients {
      let ingredient: Ingredient
      if let existing = ingredientByID[dto.id] {
        ingredient = existing
      } else {
        ingredient = Ingredient(id: dto.id, name: dto.name)
        context.insert(ingredient)
        ingredientByID[dto.id] = ingredient
      }
      ingredient.name = dto.name
      ingredient.aliases = dto.aliases
      ingredient.isHighRisk = dto.isHighRisk
      ingredient.dailyCeilingMg = dto.dailyCeilingMg
      ingredient.minIntervalMinutes = dto.minIntervalMinutes
    }

    let existingMeds = try context.fetch(FetchDescriptor<Medication>())
    var medByID = Dictionary(existingMeds.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let snapshotMedIDs = Set(medications.map(\.id))

    for dto in medications {
      let medication: Medication
      if let existing = medByID[dto.id] {
        medication = existing
      } else {
        medication = Medication(id: dto.id, displayName: dto.displayName, unitForm: dto.unitForm, kind: dto.kind)
        context.insert(medication)
        medByID[dto.id] = medication
      }
      medication.displayName = dto.displayName
      medication.fullName = dto.fullName
      medication.unitForm = dto.unitForm
      medication.kind = dto.kind
      medication.colorHex = dto.colorHex
      medication.notes = dto.notes
      medication.isArchived = dto.isArchived
      medication.createdAt = dto.createdAt
      medication.healthKitConceptID = dto.healthKitConceptID
      medication.prnAvailableQuantities = dto.prnAvailableQuantities

      // Rebuild owned children, deleting the old rows so reassignment can't orphan them.
      for old in medication.components {
        context.delete(old)
      }
      for old in medication.schedule {
        context.delete(old)
      }
      medication.components = dto.components.map { component in
        MedicationComponent(
          id: component.id,
          ingredient: component.ingredientID.flatMap { ingredientByID[$0] },
          dosagePerUnitMg: component.dosagePerUnitMg
        )
      }
      medication.schedule = dto.schedule.map { dose in
        ScheduledDose(id: dose.id, hour: dose.hour, minute: dose.minute, quantity: dose.quantity, daysOfWeek: dose.daysOfWeek)
      }
    }

    // Archive (never delete) meds the snapshot no longer carries.
    for medication in existingMeds where !snapshotMedIDs.contains(medication.id) {
      medication.isArchived = true
    }

    try context.save()
  }
}
