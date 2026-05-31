import CryptoKit
import Foundation
import SwiftData

/// Seeds the ingredient library shipped with the app (SPEC §5.3).
///
/// **Threshold sourcing policy** (see #155):
/// - **OTC actives** carry `dailyCeilingMg` / `minIntervalMinutes` drawn from
///   FDA OTC monographs (21 CFR Part 341 cough/cold, Part 343 internal
///   analgesics) and product labeling. Per-category citations are inline in
///   each block below.
/// - **Vitamins and minerals** carry Upper Limits (ULs) from the NIH Office
///   of Dietary Supplements fact sheets where the ODS publishes one. Where
///   ODS reports "no UL established" (B-vitamins without a defined upper
///   bound, K, biotin, omega-3s, most herbal supplements), thresholds are
///   `nil` and the user fills them in if their prescriber sets one.
/// - **Prescription actives** ship as **name + alias + isHighRisk only**,
///   with `nil` thresholds. Inventing ceilings for narrow-TI Rx drugs the
///   user's prescriber owns is a medical-claim trap; the user enters what
///   their prescriber set. `isHighRisk: true` is reserved for the
///   narrow-therapeutic-index drugs the SPEC singles out as press-and-hold
///   worthy: lithium, lamotrigine, valproate, carbamazepine, levothyroxine,
///   methotrexate, warfarin, digoxin.
///
/// **Naming invariant**: a seed's `name` is its identity — `stableUUID(for:)`
/// derives the canonical ID from `name.lowercased()`. Renaming a seed silently
/// forks the UUID; existing installs keep the old baked-in row and the
/// re-seed inserts a duplicate. Use `aliases` for synonyms instead.
public enum IngredientLibrarySeeder {
  public struct SeedSpec: Sendable {
    public let name: String
    public let aliases: [String]
    public let isHighRisk: Bool
    public let dailyCeilingMg: Double?
    public let minIntervalMinutes: Int?
  }

  /// User-facing disclaimer for the seeded thresholds. Surfaced by the iPhone Ingredients/Settings UI.
  public static let disclaimer = """
  The suggested thresholds are starting points only. They are NOT medical advice. \
  Confirm every ceiling and interval with your prescriber before relying on them. \
  PillBreakfast warns; it does not lock you out.
  """

  /// IDs of the seeded library entries (derived from their canonical names). The
  /// Ingredients screen uses this to block deletion of seeded ingredients.
  /// `static let` so the SHA-1 derivation runs once, not per deletion check.
  public static let seededIDs: Set<UUID> = Set(seeds.map { stableUUID(for: $0.name) })

  public static let seeds: [SeedSpec] =
    otcAnalgesics
      + otcAntihistamines
      + otcDecongestants
      + otcCoughExpectorant
      + otcGastrointestinal
      + vitamins
      + minerals
      + supplements
      + stimulants
      + rxMaintenance

  // MARK: - OTC analgesics & antipyretics

  // Source: FDA OTC monograph, 21 CFR Part 343 (internal analgesics, antipyretics,
  // and antirheumatics). Per-active maxima reflect adult OTC labeling.

  private static let otcAnalgesics: [SeedSpec] = [
    SeedSpec(name: "Acetaminophen", aliases: ["Paracetamol", "APAP"], isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240),
    SeedSpec(name: "Ibuprofen", aliases: [], isHighRisk: false, dailyCeilingMg: 1200, minIntervalMinutes: 360),
    SeedSpec(name: "Aspirin", aliases: ["ASA", "Acetylsalicylic acid"], isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: 240),
    SeedSpec(name: "Naproxen", aliases: ["Naproxen sodium"], isHighRisk: false, dailyCeilingMg: 660, minIntervalMinutes: 720),
    SeedSpec(name: "Ketoprofen", aliases: [], isHighRisk: false, dailyCeilingMg: 75, minIntervalMinutes: 480),
  ]

  // MARK: - OTC antihistamines

  // Source: FDA OTC monograph, 21 CFR Part 341 (cold, cough, allergy, bronchodilator,
  // and antiasthmatic), plus per-active OTC product labeling.

  private static let otcAntihistamines: [SeedSpec] = [
    SeedSpec(name: "Diphenhydramine", aliases: ["Benadryl"], isHighRisk: false, dailyCeilingMg: 300, minIntervalMinutes: 240),
    SeedSpec(name: "Loratadine", aliases: ["Claritin"], isHighRisk: false, dailyCeilingMg: 10, minIntervalMinutes: 1440),
    SeedSpec(name: "Cetirizine", aliases: ["Zyrtec"], isHighRisk: false, dailyCeilingMg: 10, minIntervalMinutes: 1440),
    SeedSpec(name: "Fexofenadine", aliases: ["Allegra"], isHighRisk: false, dailyCeilingMg: 180, minIntervalMinutes: 720),
    SeedSpec(name: "Levocetirizine", aliases: ["Xyzal"], isHighRisk: false, dailyCeilingMg: 5, minIntervalMinutes: 1440),
    SeedSpec(name: "Chlorpheniramine", aliases: ["Chlor-Trimeton"], isHighRisk: false, dailyCeilingMg: 24, minIntervalMinutes: 240),
    SeedSpec(name: "Brompheniramine", aliases: [], isHighRisk: false, dailyCeilingMg: 24, minIntervalMinutes: 240),
    SeedSpec(name: "Doxylamine", aliases: ["Unisom"], isHighRisk: false, dailyCeilingMg: 75, minIntervalMinutes: 240),
    SeedSpec(name: "Triprolidine", aliases: [], isHighRisk: false, dailyCeilingMg: 10, minIntervalMinutes: 240),
    SeedSpec(name: "Pyrilamine", aliases: ["Mepyramine"], isHighRisk: false, dailyCeilingMg: 200, minIntervalMinutes: 360),
  ]

  // MARK: - OTC decongestants

  // Source: FDA OTC monograph, 21 CFR Part 341 (oral and nasal decongestants).
  // Intranasal oxymetazoline is listed name-only because its dosing is per-spray
  // and the per-spray mg load isn't user-friendly to track on a mg basis.

  private static let otcDecongestants: [SeedSpec] = [
    SeedSpec(name: "Pseudoephedrine", aliases: ["Sudafed"], isHighRisk: false, dailyCeilingMg: 240, minIntervalMinutes: 240),
    SeedSpec(name: "Phenylephrine", aliases: [], isHighRisk: false, dailyCeilingMg: 60, minIntervalMinutes: 240),
    SeedSpec(name: "Oxymetazoline", aliases: ["Afrin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
  ]

  // MARK: - OTC cough & expectorant

  // Source: FDA OTC monograph, 21 CFR Part 341.

  private static let otcCoughExpectorant: [SeedSpec] = [
    SeedSpec(name: "Guaifenesin", aliases: ["Mucinex"], isHighRisk: false, dailyCeilingMg: 2400, minIntervalMinutes: 240),
    SeedSpec(name: "Dextromethorphan", aliases: ["DXM", "DM"], isHighRisk: false, dailyCeilingMg: 120, minIntervalMinutes: 240),
    SeedSpec(name: "Menthol", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
  ]

  // MARK: - OTC gastrointestinal

  // Sources: FDA OTC monographs for H2 antagonists (21 CFR Part 336), antacids,
  // and laxatives; per-product OTC labeling for PPIs (omeprazole, lansoprazole,
  // esomeprazole approved as OTC under their respective NDAs).

  private static let otcGastrointestinal: [SeedSpec] = [
    SeedSpec(name: "Famotidine", aliases: ["Pepcid"], isHighRisk: false, dailyCeilingMg: 80, minIntervalMinutes: 720),
    SeedSpec(name: "Omeprazole", aliases: ["Prilosec"], isHighRisk: false, dailyCeilingMg: 20, minIntervalMinutes: 1440),
    SeedSpec(name: "Lansoprazole", aliases: ["Prevacid"], isHighRisk: false, dailyCeilingMg: 15, minIntervalMinutes: 1440),
    SeedSpec(name: "Esomeprazole", aliases: ["Nexium"], isHighRisk: false, dailyCeilingMg: 20, minIntervalMinutes: 1440),
    SeedSpec(name: "Loperamide", aliases: ["Imodium"], isHighRisk: false, dailyCeilingMg: 8, minIntervalMinutes: 240),
    SeedSpec(name: "Bismuth subsalicylate", aliases: ["Pepto-Bismol"], isHighRisk: false, dailyCeilingMg: 4200, minIntervalMinutes: 60),
    SeedSpec(name: "Simethicone", aliases: ["Gas-X"], isHighRisk: false, dailyCeilingMg: 500, minIntervalMinutes: 360),
    SeedSpec(name: "Calcium carbonate", aliases: ["Tums"], isHighRisk: false, dailyCeilingMg: 7500, minIntervalMinutes: 60),
    SeedSpec(name: "Magnesium hydroxide", aliases: ["Milk of Magnesia"], isHighRisk: false, dailyCeilingMg: 2400, minIntervalMinutes: 360),
    SeedSpec(name: "Docusate", aliases: ["Colace"], isHighRisk: false, dailyCeilingMg: 500, minIntervalMinutes: 720),
    SeedSpec(name: "Senna", aliases: ["Senokot"], isHighRisk: false, dailyCeilingMg: 100, minIntervalMinutes: 1440),
    SeedSpec(name: "Polyethylene glycol 3350", aliases: ["MiraLAX", "PEG 3350"], isHighRisk: false, dailyCeilingMg: 17000, minIntervalMinutes: 1440),
    SeedSpec(name: "Psyllium", aliases: ["Metamucil"], isHighRisk: false, dailyCeilingMg: 30000, minIntervalMinutes: 480),
    SeedSpec(name: "Bisacodyl", aliases: ["Dulcolax"], isHighRisk: false, dailyCeilingMg: 30, minIntervalMinutes: 1440),
  ]

  // MARK: - Vitamins

  // Source: NIH Office of Dietary Supplements (ODS) Tolerable Upper Intake Levels
  // for adults 19+. Where ODS notes "no UL established" the threshold is nil.
  // Daily Value conversions: 1 mcg cholecalciferol = 40 IU; 1 mg alpha-tocopherol
  // = 1.49 IU; 1 mcg RAE retinol = 3.33 IU.

  private static let vitamins: [SeedSpec] = [
    SeedSpec(name: "Vitamin A", aliases: ["Retinol"], isHighRisk: false, dailyCeilingMg: 3, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B1", aliases: ["Thiamine", "Thiamin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B2", aliases: ["Riboflavin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B3 (Niacin)", aliases: ["Nicotinic acid"], isHighRisk: false, dailyCeilingMg: 35, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B3 (Niacinamide)", aliases: ["Nicotinamide"], isHighRisk: false, dailyCeilingMg: 35, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B5", aliases: ["Pantothenic acid"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B6", aliases: ["Pyridoxine"], isHighRisk: false, dailyCeilingMg: 100, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B7", aliases: ["Biotin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B9", aliases: ["Folate", "Folic acid"], isHighRisk: false, dailyCeilingMg: 1, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin B12", aliases: ["Cobalamin", "Cyanocobalamin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin C", aliases: ["Ascorbic acid"], isHighRisk: false, dailyCeilingMg: 2000, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin D3", aliases: ["Cholecalciferol"], isHighRisk: false, dailyCeilingMg: 0.1, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin D2", aliases: ["Ergocalciferol"], isHighRisk: false, dailyCeilingMg: 0.1, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin E", aliases: ["Alpha-tocopherol", "Tocopherol"], isHighRisk: false, dailyCeilingMg: 1000, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin K1", aliases: ["Phylloquinone"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Vitamin K2", aliases: ["Menaquinone"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Choline", aliases: [], isHighRisk: false, dailyCeilingMg: 3500, minIntervalMinutes: nil),
  ]

  // MARK: - Minerals

  // Source: NIH ODS ULs for adults 19+. Magnesium UL is for supplemental forms
  // only (food magnesium not counted). Where ODS notes no UL the value is nil.

  private static let minerals: [SeedSpec] = [
    SeedSpec(name: "Calcium", aliases: [], isHighRisk: false, dailyCeilingMg: 2500, minIntervalMinutes: nil),
    SeedSpec(name: "Magnesium", aliases: [], isHighRisk: false, dailyCeilingMg: 350, minIntervalMinutes: nil),
    SeedSpec(name: "Zinc", aliases: [], isHighRisk: false, dailyCeilingMg: 40, minIntervalMinutes: nil),
    SeedSpec(name: "Iron", aliases: ["Ferrous sulfate", "Ferrous gluconate"], isHighRisk: false, dailyCeilingMg: 45, minIntervalMinutes: nil),
    SeedSpec(name: "Selenium", aliases: [], isHighRisk: false, dailyCeilingMg: 0.4, minIntervalMinutes: nil),
    SeedSpec(name: "Copper", aliases: [], isHighRisk: false, dailyCeilingMg: 10, minIntervalMinutes: nil),
    SeedSpec(name: "Manganese", aliases: [], isHighRisk: false, dailyCeilingMg: 11, minIntervalMinutes: nil),
    SeedSpec(name: "Chromium", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Iodine", aliases: [], isHighRisk: false, dailyCeilingMg: 1.1, minIntervalMinutes: nil),
    SeedSpec(name: "Potassium", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Phosphorus", aliases: [], isHighRisk: false, dailyCeilingMg: 4000, minIntervalMinutes: nil),
    SeedSpec(name: "Boron", aliases: [], isHighRisk: false, dailyCeilingMg: 20, minIntervalMinutes: nil),
    SeedSpec(name: "Molybdenum", aliases: [], isHighRisk: false, dailyCeilingMg: 2, minIntervalMinutes: nil),
  ]

  // MARK: - Supplements

  // ODS publishes no UL for any of these. They ship name-only so autocomplete
  // surfaces them and the user fills in whatever their prescriber sets.

  private static let supplements: [SeedSpec] = [
    SeedSpec(name: "Melatonin", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Omega-3 EPA", aliases: ["Eicosapentaenoic acid"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Omega-3 DHA", aliases: ["Docosahexaenoic acid"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Fish oil", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Coenzyme Q10", aliases: ["CoQ10", "Ubiquinone", "Ubiquinol"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Glucosamine", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Chondroitin", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Turmeric", aliases: ["Curcumin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Ashwagandha", aliases: ["Withania somnifera"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Garlic extract", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Ginkgo biloba", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Milk thistle", aliases: ["Silymarin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Probiotics", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
  ]

  // MARK: - Stimulants

  // Caffeine: FDA cites 400 mg/day as the moderate-adult ceiling for healthy adults.
  // Taurine and L-theanine ship name-only — neither has an ODS UL.

  private static let stimulants: [SeedSpec] = [
    SeedSpec(name: "Caffeine", aliases: [], isHighRisk: false, dailyCeilingMg: 400, minIntervalMinutes: nil),
    SeedSpec(name: "Taurine", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "L-theanine", aliases: ["Theanine"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
  ]

  // MARK: - Prescription maintenance

  // Name + aliases + isHighRisk only — all thresholds nil. Dosing for these is
  // owned by the user's prescriber; PillBreakfast doesn't invent ceilings for
  // narrow-TI Rx drugs. `isHighRisk: true` is reserved for the
  // narrow-therapeutic-index drugs the SPEC singles out as press-and-hold
  // worthy (lithium, lamotrigine, valproate, carbamazepine, levothyroxine,
  // methotrexate, warfarin, digoxin).

  private static let rxMaintenance: [SeedSpec] = [
    // Mood / psychiatric
    SeedSpec(name: "Lithium carbonate", aliases: ["Lithium"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Sertraline", aliases: ["Zoloft"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Fluoxetine", aliases: ["Prozac"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Citalopram", aliases: ["Celexa"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Escitalopram", aliases: ["Lexapro"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Paroxetine", aliases: ["Paxil"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Venlafaxine", aliases: ["Effexor"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Duloxetine", aliases: ["Cymbalta"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Bupropion", aliases: ["Wellbutrin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Mirtazapine", aliases: ["Remeron"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    // Anticonvulsants / mood stabilisers
    SeedSpec(name: "Lamotrigine", aliases: ["Lamictal"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Valproate", aliases: ["Valproic acid", "Depakote", "Divalproex"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Carbamazepine", aliases: ["Tegretol"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Gabapentin", aliases: ["Neurontin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Pregabalin", aliases: ["Lyrica"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    // Benzodiazepines
    SeedSpec(name: "Clonazepam", aliases: ["Klonopin"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Alprazolam", aliases: ["Xanax"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Lorazepam", aliases: ["Ativan"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Diazepam", aliases: ["Valium"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    // Cardiovascular
    SeedSpec(name: "Atorvastatin", aliases: ["Lipitor"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Rosuvastatin", aliases: ["Crestor"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Simvastatin", aliases: ["Zocor"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Pravastatin", aliases: ["Pravachol"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Lisinopril", aliases: ["Prinivil", "Zestril"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Losartan", aliases: ["Cozaar"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Amlodipine", aliases: ["Norvasc"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Metoprolol", aliases: ["Lopressor", "Toprol"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Propranolol", aliases: ["Inderal"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Digoxin", aliases: ["Lanoxin"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Warfarin", aliases: ["Coumadin"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    // Metabolic / endocrine
    SeedSpec(name: "Metformin", aliases: ["Glucophage"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Glipizide", aliases: ["Glucotrol"], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Levothyroxine", aliases: ["Synthroid", "Levoxyl"], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
    // Anti-inflammatory / immunosuppressive
    SeedSpec(name: "Prednisone", aliases: [], isHighRisk: false, dailyCeilingMg: nil, minIntervalMinutes: nil),
    SeedSpec(name: "Methotrexate", aliases: [], isHighRisk: true, dailyCeilingMg: nil, minIntervalMinutes: nil),
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
