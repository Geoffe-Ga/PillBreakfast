import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct SafetyEvaluatorTests {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)
  /// Pinned to UTC so "today" boundaries are deterministic regardless of the
  /// runner's timezone (the prior doses sit a few hours before `now`).
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  private func makeIngredient(
    _ name: String,
    ceiling: Double? = nil,
    interval: Int? = nil,
    in context: ModelContext
  ) -> Ingredient {
    let ingredient = Ingredient(name: name, dailyCeilingMg: ceiling, minIntervalMinutes: interval)
    context.insert(ingredient)
    return ingredient
  }

  private func makeMed(
    _ name: String,
    components: [(Ingredient, Double)],
    in context: ModelContext
  ) -> Medication {
    let med = Medication(displayName: name, unitForm: .tablet, kind: .prn)
    med.components = components.map { MedicationComponent(ingredient: $0.0, dosagePerUnitMg: $0.1) }
    context.insert(med)
    return med
  }

  /// Logs a prior `.taken` dose carrying a frozen ingredient-amount snapshot.
  private func logDose(_ ingredientID: UUID, mg: Double, at takenAt: Date, in context: ModelContext) {
    context.insert(DoseEvent(
      takenAt: takenAt,
      quantity: 1,
      status: .taken,
      loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: ingredientID, ingredientName: "test", totalMg: mg)]
    ))
  }

  private func ceilingViolation(in violations: [Violation]) -> (current: Double, proposed: Double, ceiling: Double)? {
    for case let .ceiling(_, current, proposed, ceiling) in violations {
      return (current, proposed, ceiling)
    }
    return nil
  }

  private func hasTooSoon(in violations: [Violation]) -> Bool {
    violations.contains { if case .tooSoon = $0 { true } else { false } }
  }

  // MARK: - Phase 4 gate tests

  @Test func gabapentinSelfPacing() throws {
    // Daily-ceiling check fires when the cumulative day total would exceed it.
    let context = try makeContext()
    let gabapentin = makeIngredient("Gabapentin", ceiling: 3600, in: context)
    let neurontin = makeMed("Neurontin", components: [(gabapentin, 300)], in: context)
    logDose(gabapentin.id, mg: 3000, at: now.addingTimeInterval(-2 * 3600), in: context)
    try context.save()

    // Proposing 3 × 300 = 900 → 3000 + 900 = 3900 > 3600.
    let violations = try SafetyEvaluator.violationsIfTaken(neurontin, quantity: 3, at: now, in: context, calendar: calendar)
    let ceiling = try #require(ceilingViolation(in: violations))
    #expect(ceiling.current == 3000)
    #expect(ceiling.proposed == 3900)
    #expect(ceiling.ceiling == 3600)
  }

  @Test func tylenolSelfPacing() throws {
    // Min-interval check fires when re-dosing sooner than allowed.
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, interval: 240, in: context)
    let tylenol = makeMed("Tylenol", components: [(apap, 500)], in: context)
    // Last dose 2h ago (120 min < 240).
    logDose(apap.id, mg: 1000, at: now.addingTimeInterval(-2 * 3600), in: context)
    try context.save()

    let violations = try SafetyEvaluator.violationsIfTaken(tylenol, quantity: 2, at: now, in: context, calendar: calendar)
    #expect(hasTooSoon(in: violations))
    // 1000 + (2 × 500) = 2000, well under 4000 — no ceiling violation.
    #expect(ceilingViolation(in: violations) == nil)
  }

  @Test func crossProductTylenolPlusExcedrinTripsAcetaminophenCeiling() throws {
    // The cross-product safety case: acetaminophen from a prior Tylenol dose plus
    // the acetaminophen in Excedrin together exceed the 4000mg ceiling, even though
    // neither product alone would. (SPEC §10 Phase 4 case 3 phrases this as "1500mg
    // Tylenol + 4 Excedrin"; that arithmetic is 1500 + 1000 = 2500 < 4000 and does
    // NOT trip — see Gap 1 in the PR. Fixture adjusted to a prior 3500mg so the
    // ceiling legitimately fires.)
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, interval: 240, in: context)
    let aspirin = makeIngredient("Aspirin", in: context)
    let caffeine = makeIngredient("Caffeine", in: context)
    let excedrin = makeMed(
      "Excedrin Extra Strength",
      components: [(apap, 250), (aspirin, 250), (caffeine, 65)],
      in: context
    )
    // Prior standalone Tylenol: 3500mg acetaminophen, 5h ago (> 240 min, so the
    // interval rule does NOT fire — this isolates the ceiling violation).
    logDose(apap.id, mg: 3500, at: now.addingTimeInterval(-5 * 3600), in: context)
    try context.save()

    // 4 Excedrin → 4 × 250 = 1000mg acetaminophen → 3500 + 1000 = 4500 > 4000.
    let violations = try SafetyEvaluator.violationsIfTaken(excedrin, quantity: 4, at: now, in: context, calendar: calendar)
    let ceiling = try #require(ceilingViolation(in: violations))
    #expect(ceiling.current == 3500)
    #expect(ceiling.proposed == 4500)
    #expect(ceiling.ceiling == 4000)
    #expect(!hasTooSoon(in: violations)) // prior dose was 5h ago
  }

  // MARK: - Negative / stacking

  @Test func doseLandingExactlyOnCeilingIsAllowed() throws {
    // Pins the `>` (not `>=`) semantics: a dose that brings the day total to
    // exactly the ceiling is allowed — only exceeding it is a violation.
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 1000, in: context)
    let tylenol = makeMed("Tylenol", components: [(apap, 500)], in: context)
    logDose(apap.id, mg: 500, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    // 500 + (1 × 500) = 1000 == ceiling → no violation.
    #expect(try SafetyEvaluator.violationsIfTaken(tylenol, quantity: 1, at: now, in: context, calendar: calendar).isEmpty)
  }

  @Test func clearedRegimenHasNoViolations() throws {
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, interval: 240, in: context)
    let tylenol = makeMed("Tylenol", components: [(apap, 500)], in: context)
    try context.save()

    // No prior doses; a single 2-tablet dose (1000mg) is well within limits.
    #expect(try SafetyEvaluator.violationsIfTaken(tylenol, quantity: 2, at: now, in: context, calendar: calendar).isEmpty)
  }

  @Test func ingredientWithNoConstraintsIsAlwaysSafe() throws {
    // A plain vitamin: no ceiling, no interval — both guards short-circuit.
    let context = try makeContext()
    let vitaminD = makeIngredient("Vitamin D", in: context) // ceiling/interval nil
    let supplement = makeMed("Vitamin D", components: [(vitaminD, 2000)], in: context)
    logDose(vitaminD.id, mg: 50000, at: now.addingTimeInterval(-60), in: context) // huge + recent
    try context.save()

    #expect(try SafetyEvaluator.violationsIfTaken(supplement, quantity: 5, at: now, in: context, calendar: calendar).isEmpty)
  }

  @Test func medicationWithNoComponentsIsAlwaysSafe() throws {
    let context = try makeContext()
    let med = makeMed("Mystery", components: [], in: context)
    try context.save()

    #expect(try SafetyEvaluator.violationsIfTaken(med, quantity: 1, at: now, in: context, calendar: calendar).isEmpty)
  }

  @Test func duplicateIngredientComponentsAggregateBeforeCeilingCheck() throws {
    // EPIC_05_ISSUE_06 combo-product setup: one med carrying the same
    // ingredient in two components (two acetaminophen sources, e.g. a brand
    // dose plus a generic filler). The under-count failure mode would be
    // each component evaluated independently — 250 × 4 = 1000mg per
    // component, both below the 1000mg ceiling. The correct safety-aware
    // answer aggregates first: 2 × 250 × 4 = 2000mg, well above the
    // ceiling, exactly one `.ceiling` violation produced.
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 1000, in: context)
    let combo = Medication(displayName: "Combo APAP", unitForm: .tablet, kind: .prn)
    combo.components = [
      MedicationComponent(ingredient: apap, dosagePerUnitMg: 250),
      MedicationComponent(ingredient: apap, dosagePerUnitMg: 250),
    ]
    context.insert(combo)
    try context.save()

    let violations = try SafetyEvaluator.violationsIfTaken(combo, quantity: 4, at: now, in: context, calendar: calendar)
    #expect(violations.count == 1)
    let summary = try #require(ceilingViolation(in: violations))
    #expect(summary.proposed == 2000)
    #expect(summary.current == 0)
    #expect(summary.ceiling == 1000)
  }

  @Test func duplicateIngredientComponentsProduceSingleTooSoonViolation() throws {
    // Same combo-product shape; this time the ingredient just took a recent
    // dose. Per-component evaluation would emit *two* `.tooSoon` entries for
    // the same ingredient — aggregation collapses them to one.
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", interval: 240, in: context)
    let combo = Medication(displayName: "Combo APAP", unitForm: .tablet, kind: .prn)
    combo.components = [
      MedicationComponent(ingredient: apap, dosagePerUnitMg: 250),
      MedicationComponent(ingredient: apap, dosagePerUnitMg: 250),
    ]
    context.insert(combo)
    logDose(apap.id, mg: 500, at: now.addingTimeInterval(-3600), in: context) // 1h ago, < 240min interval
    try context.save()

    let violations = try SafetyEvaluator.violationsIfTaken(combo, quantity: 1, at: now, in: context, calendar: calendar)
    #expect(violations.count == 1)
    #expect(hasTooSoon(in: violations))
  }

  @Test func ceilingAndIntervalStackOnWorstCaseDose() throws {
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, interval: 240, in: context)
    let tylenol = makeMed("Tylenol", components: [(apap, 500)], in: context)
    // 3500mg taken 1h ago: too soon (60 < 240) AND near the ceiling.
    logDose(apap.id, mg: 3500, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    // 2 × 500 = 1000 → 3500 + 1000 = 4500 > 4000, and only 1h since the last dose.
    let violations = try SafetyEvaluator.violationsIfTaken(tylenol, quantity: 2, at: now, in: context, calendar: calendar)
    #expect(violations.count == 2)
    #expect(ceilingViolation(in: violations) != nil)
    #expect(hasTooSoon(in: violations))
  }
}
