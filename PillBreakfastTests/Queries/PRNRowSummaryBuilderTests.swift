import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PRNRowSummaryBuilderTests {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)
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

  private func makeIngredient(_ name: String, ceiling: Double? = nil, in context: ModelContext) -> Ingredient {
    let ingredient = Ingredient(name: name, dailyCeilingMg: ceiling)
    context.insert(ingredient)
    return ingredient
  }

  private func makeMed(_ name: String, components: [(Ingredient, Double)], in context: ModelContext) -> Medication {
    let med = Medication(displayName: name, unitForm: .tablet, kind: .prn)
    med.components = components.map { MedicationComponent(ingredient: $0.0, dosagePerUnitMg: $0.1) }
    context.insert(med)
    return med
  }

  private func logProductDose(_ med: Medication, ingredientID: UUID, name: String, mg: Double, at takenAt: Date, in context: ModelContext) {
    context.insert(DoseEvent(
      medication: med,
      scheduledFor: nil,
      takenAt: takenAt,
      quantity: 1,
      status: .taken,
      loggedOn: .watch,
      ingredientAmounts: [LoggedIngredientAmount(ingredientID: ingredientID, ingredientName: name, totalMg: mg)]
    ))
  }

  @Test func singleIngredientPrescriptionVariant() throws {
    // Product name matches ingredient name → "N mg today" (no ingredient name).
    let context = try makeContext()
    let gabapentin = makeIngredient("Gabapentin", in: context)
    let med = makeMed("Gabapentin", components: [(gabapentin, 300)], in: context)
    logProductDose(med, ingredientID: gabapentin.id, name: "Gabapentin", mg: 600, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    let summary = try PRNRowSummaryBuilder.summary(for: med, at: now, in: context, calendar: calendar)
    #expect(summary.firstLine == "Gabapentin")
    #expect(summary.secondLine.contains("600 mg today"))
    #expect(!summary.secondLine.contains("gabapentin today")) // not the OTC ingredient-named form
    #expect(summary.secondLine.contains("last "))
    #expect(summary.highlightedIngredientID == gabapentin.id)
  }

  @Test func singleIngredientOTCVariant() throws {
    // Product name differs from ingredient → "N mg acetaminophen today".
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, in: context)
    let med = makeMed("Tylenol", components: [(apap, 500)], in: context)
    logProductDose(med, ingredientID: apap.id, name: "Acetaminophen", mg: 1500, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    let summary = try PRNRowSummaryBuilder.summary(for: med, at: now, in: context, calendar: calendar)
    #expect(summary.firstLine == "Tylenol")
    #expect(summary.secondLine.contains("1500 mg acetaminophen today"))
    #expect(summary.highlightedIngredientID == apap.id)
  }

  @Test func comboVariantSurfacesHighestUtilizationIngredient() throws {
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, in: context)
    let aspirin = makeIngredient("Aspirin", in: context) // no ceiling
    let caffeine = makeIngredient("Caffeine", in: context) // no ceiling
    let med = makeMed("Excedrin Extra Strength", components: [(apap, 250), (aspirin, 250), (caffeine, 65)], in: context)
    // 1000mg acetaminophen so far today = 25% of the 4000 ceiling.
    logProductDose(med, ingredientID: apap.id, name: "Acetaminophen", mg: 1000, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    let summary = try PRNRowSummaryBuilder.summary(for: med, at: now, in: context, calendar: calendar)
    #expect(summary.firstLine == "Excedrin Extra Strength")
    #expect(summary.secondLine.contains("acetaminophen 25% of daily limit"))
    #expect(summary.highlightedIngredientID == apap.id)
  }

  @Test func comboVariantWithNoCeilingsOmitsUtilizationSuffix() throws {
    // Every ingredient in the combo lacks a ceiling — `bestSuffix` is empty
    // and the second line is just the last-dose text, with no "% of daily
    // limit" suffix to hang utilization on.
    let context = try makeContext()
    let aspirin = makeIngredient("Aspirin", in: context) // no ceiling
    let caffeine = makeIngredient("Caffeine", in: context) // no ceiling
    let med = makeMed("Plain Combo", components: [(aspirin, 250), (caffeine, 65)], in: context)
    // Only Aspirin's dose is logged — caffeine deliberately untouched. We're
    // verifying the no-ceiling branch is reached at all, not which ingredient
    // is highlighted (there's no highlight since neither has a ceiling).
    logProductDose(med, ingredientID: aspirin.id, name: "Aspirin", mg: 250, at: now.addingTimeInterval(-3600), in: context)
    try context.save()

    let summary = try PRNRowSummaryBuilder.summary(for: med, at: now, in: context, calendar: calendar)
    #expect(summary.firstLine == "Plain Combo")
    // Last-dose text is present; no "% of daily limit" suffix.
    #expect(summary.secondLine.contains("last "))
    #expect(!summary.secondLine.contains("% of daily limit"))
    #expect(summary.highlightedIngredientID == nil)
  }

  @Test func noDosesYetWhenProductNeverTaken() throws {
    let context = try makeContext()
    let apap = makeIngredient("Acetaminophen", ceiling: 4000, in: context)
    let med = makeMed("Tylenol", components: [(apap, 500)], in: context)
    try context.save()

    let summary = try PRNRowSummaryBuilder.summary(for: med, at: now, in: context, calendar: calendar)
    #expect(summary.secondLine.contains("no doses yet"))
    #expect(summary.secondLine.contains("0 mg acetaminophen today"))
  }
}
