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

  public let schemaVersion: Int
  public let ingredients: [IngredientDTO]
  public let medications: [MedicationDTO]

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

/// Errors raised while converting between the SwiftData store and a ``RegimenSnapshot``.
public enum SyncError: Error, Equatable, Sendable {
  /// A snapshot was produced by a newer app version than this device understands.
  case unsupportedSchemaVersion(Int)
  /// The store holds a component with no ingredient — an integrity violation, not a valid sync state.
  case orphanedComponent(componentID: UUID)
  /// A snapshot component references an ingredient that is in neither the snapshot nor the store.
  case danglingIngredientReference(componentID: UUID, ingredientID: UUID)
  /// A scheduled dose carries an out-of-range hour/minute/weekday that would silently break notification scheduling.
  case invalidSchedule(doseID: UUID)
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
  // Non-optional: every component must reference an ingredient, since PRN ceiling
  // math depends on it. A missing reference is an integrity error, surfaced eagerly.
  public let ingredientID: UUID
  public let dosagePerUnitMg: Double

  public init(id: UUID, ingredientID: UUID, dosagePerUnitMg: Double) {
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
  public let daysOfWeek: [Int] // ISO weekdays 1...7 (Mon...Sun); empty means every day

  public init(id: UUID, hour: Int, minute: Int, quantity: Int, daysOfWeek: [Int]) {
    self.id = id
    self.hour = hour
    self.minute = minute
    self.quantity = quantity
    self.daysOfWeek = daysOfWeek
  }

  /// True when the wall-clock fields and ISO weekdays are in range. `apply(to:)`
  /// rejects snapshots carrying an invalid dose before it touches the store.
  public var isValid: Bool {
    (0 ... 23).contains(hour)
      && (0 ... 59).contains(minute)
      && daysOfWeek.allSatisfy((1 ... 7).contains)
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

    // Only active meds sync to the watch — it logs against the live regimen, and
    // including archived history would bloat every WCSession payload over time.
    let activeMeds = FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived })

    let medications = try context.fetch(activeMeds).map { medication in
      try MedicationDTO(
        id: medication.id,
        displayName: medication.displayName,
        fullName: medication.fullName,
        unitForm: medication.unitForm,
        kind: medication.kind,
        colorHex: medication.colorHex,
        notes: medication.notes,
        // Always false given the active-meds predicate above; preserved for manual
        // snapshot construction and forward compatibility.
        isArchived: medication.isArchived,
        createdAt: medication.createdAt,
        healthKitConceptID: medication.healthKitConceptID,
        prnAvailableQuantities: medication.prnAvailableQuantities,
        components: medication.components.map { component in
          guard let ingredientID = component.ingredient?.id else {
            throw SyncError.orphanedComponent(componentID: component.id)
          }
          return ComponentDTO(id: component.id, ingredientID: ingredientID, dosagePerUnitMg: component.dosagePerUnitMg)
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
  ///
  /// Validation runs fully before any mutation: if the snapshot is rejected
  /// (unsupported schema version, or a component referencing an unknown
  /// ingredient) the call throws without touching `context`, so the caller may
  /// safely reuse the same `ModelContext`.
  @MainActor
  func apply(to context: ModelContext) throws {
    // Reject snapshots from a future app version rather than risk corrupting the
    // store in a mixed-version pairing (e.g. iPhone updated, watch not yet).
    // Deliberate `<=`: accept this version or an older one (older snapshots stay
    // readable as the schema grows additively) but reject a newer one. When a v2
    // schema lands this becomes a floor check plus a migration table.
    guard schemaVersion <= RegimenSnapshot.currentSchemaVersion else {
      throw SyncError.unsupportedSchemaVersion(schemaVersion)
    }

    var ingredientByID = try Dictionary(
      context.fetch(FetchDescriptor<Ingredient>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    // Validate-before-mutate: every component must resolve to an ingredient that
    // already exists or is being inserted by this snapshot, and every scheduled
    // dose must be in range. Checking up front means a rejected snapshot can't
    // leave the context half-rebuilt.
    let resolvableIngredientIDs = Set(ingredientByID.keys).union(ingredients.map(\.id))
    for medication in medications {
      for component in medication.components where !resolvableIngredientIDs.contains(component.ingredientID) {
        throw SyncError.danglingIngredientReference(
          componentID: component.id,
          ingredientID: component.ingredientID
        )
      }
      for dose in medication.schedule where !dose.isValid {
        // The notification scheduler is the primary enforcement point, but apply()
        // is the last boundary before bad data enters the store.
        throw SyncError.invalidSchedule(doseID: dose.id)
      }
    }

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
      // Ingredient references were validated above, so the lookup is non-nil here.
      for old in medication.components {
        context.delete(old)
      }
      for old in medication.schedule {
        context.delete(old)
      }
      medication.components = dto.components.map { component in
        let ingredient = ingredientByID[component.ingredientID]
        // Guaranteed non-nil by the validation pass above; assert so a future
        // divergence between validation and mutation is caught in tests/debug
        // rather than silently producing an ingredient-less component.
        assert(ingredient != nil, "component \(component.id) references unresolved ingredient \(component.ingredientID)")
        return MedicationComponent(id: component.id, ingredient: ingredient, dosagePerUnitMg: component.dosagePerUnitMg)
      }
      medication.schedule = dto.schedule.map { dose in
        ScheduledDose(id: dose.id, hour: dose.hour, minute: dose.minute, quantity: dose.quantity, daysOfWeek: dose.daysOfWeek)
      }
    }

    // Archive (never delete) meds the snapshot no longer carries.
    for medication in existingMeds where !snapshotMedIDs.contains(medication.id) {
      medication.isArchived = true
    }

    // Ingredients are intentionally left in place: they are a shared library keyed
    // by stable ID, so a med dropping out of the snapshot must not orphan-delete an
    // ingredient another med (or a future med) still references. Ingredient
    // lifecycle/dedup is tracked separately (issue #82).

    try context.save()
  }
}
