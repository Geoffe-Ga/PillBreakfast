import CryptoKit
import Foundation
import SwiftData

/// Seeds a small library of common OTC ingredients on first launch (SPEC §5.3).
///
/// The dailyCeilingMg / minIntervalMinutes values below are *suggested starting
/// points* drawn from publicly available OTC labeling guidance — they are NOT
/// medical advice and are user-overridable. Sources (by name; confirm current
/// labeling with a prescriber):
///   - Acetaminophen: FDA OTC labeling — 4000 mg/day max, dose every 4 h.
///   - Ibuprofen:     FDA OTC labeling — 1200 mg/day OTC max, dose every 6 h.
///   - Aspirin:       FDA OTC labeling — 4000 mg/day max, dose every 4 h.
///   - Naproxen:      FDA OTC labeling — 660 mg/day OTC max, dose every 8–12 h.
///   - Diphenhydramine: FDA OTC labeling — 300 mg/day max, dose every 4–6 h.
///   - Caffeine:      FDA — 400 mg/day commonly cited as the moderate-adult ceiling.
public enum IngredientLibrarySeeder {
  public struct SeedSpec: Sendable {
    public let name: String
    public let aliases: [String]
    public let isHighRisk: Bool
    public let dailyCeilingMg: Double?
    public let minIntervalMinutes: Int?
  }

  /// User-facing disclaimer for the seeded thresholds. Surfaced by the iPhone Ingredients/Settings UI later (EPIC 05).
  public static let disclaimer = """
  The suggested thresholds are starting points only. They are NOT medical advice. \
  Confirm every ceiling and interval with your prescriber before relying on them. \
  PillBreakfast warns; it does not lock you out.
  """

  /// IDs of the seeded library entries (derived from their canonical names). The
  /// Ingredients screen uses this to block deletion of seeded ingredients.
  public static var seededIDs: Set<UUID> {
    Set(seeds.map { stableUUID(for: $0.name) })
  }

  public static let seeds: [SeedSpec] = [
    SeedSpec(
      name: "Acetaminophen",
      aliases: ["Paracetamol", "APAP"],
      isHighRisk: false,
      dailyCeilingMg: 4000,
      minIntervalMinutes: 240
    ),
    SeedSpec(
      name: "Ibuprofen",
      aliases: [],
      isHighRisk: false,
      dailyCeilingMg: 1200,
      minIntervalMinutes: 360
    ),
    SeedSpec(
      name: "Aspirin",
      aliases: ["ASA"],
      isHighRisk: false,
      dailyCeilingMg: 4000,
      minIntervalMinutes: 240
    ),
    SeedSpec(
      name: "Naproxen",
      aliases: ["Naproxen Sodium"],
      isHighRisk: false,
      dailyCeilingMg: 660,
      minIntervalMinutes: 720
    ),
    SeedSpec(
      name: "Diphenhydramine",
      aliases: [],
      isHighRisk: false,
      dailyCeilingMg: 300,
      minIntervalMinutes: 240
    ),
    SeedSpec(
      name: "Caffeine",
      aliases: [],
      isHighRisk: false,
      dailyCeilingMg: 400,
      minIntervalMinutes: nil
    ),
  ]

  /// Inserts any missing seed ingredient and is a no-op for already-present ones.
  ///
  /// Dedup is keyed on ``stableUUID(for:)`` (derived from the case-folded name),
  /// so re-running — or re-seeding a wiped install — reuses the same canonical
  /// IDs and never forks the graph across devices.
  @MainActor
  public static func seedIfNeeded(context: ModelContext) throws {
    let existing = try Set(context.fetch(FetchDescriptor<Ingredient>()).map(\.id))
    var inserted = false
    for spec in seeds {
      let id = stableUUID(for: spec.name)
      guard !existing.contains(id) else { continue }
      context.insert(
        Ingredient(
          id: id,
          name: spec.name,
          aliases: spec.aliases,
          isHighRisk: spec.isHighRisk,
          dailyCeilingMg: spec.dailyCeilingMg,
          minIntervalMinutes: spec.minIntervalMinutes
        )
      )
      inserted = true
    }
    // Avoid a no-op write round-trip on launches where the library is already seeded.
    if inserted {
      try context.save()
    }
  }

  /// Fixed namespace for PillBreakfast ingredient identifiers. Built from raw
  /// bytes (not a string literal) to avoid an optional / force-unwrap.
  private static let namespace = UUID(
    uuid: (0x6B, 0x1B, 0x3C, 0x2A, 0x0E, 0x5D, 0x4F, 0x7A, 0x9C, 0x2E, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F)
  )

  /// Deterministic RFC 4122 v5 (SHA-1) UUID from the namespace and the case-folded ingredient name.
  static func stableUUID(for name: String) -> UUID {
    let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
    var data = Data(namespaceBytes)
    data.append(contentsOf: Array(name.lowercased().utf8))

    var digest = Array(Insecure.SHA1.hash(data: data))
    digest[6] = (digest[6] & 0x0F) | 0x50 // version 5
    digest[8] = (digest[8] & 0x3F) | 0x80 // RFC 4122 variant

    return UUID(uuid: (
      digest[0], digest[1], digest[2], digest[3],
      digest[4], digest[5], digest[6], digest[7],
      digest[8], digest[9], digest[10], digest[11],
      digest[12], digest[13], digest[14], digest[15]
    ))
  }
}
