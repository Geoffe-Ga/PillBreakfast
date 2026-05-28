import Foundation
@testable import PillBreakfast_Watch_App_Watch_App
import SwiftData
import Testing

@MainActor
struct SchemaSmokeTests {
  @Test func containerOpensWithModelGraph() throws {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    let ingredient = Ingredient()
    context.insert(ingredient)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Ingredient>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.id == ingredient.id)
  }
}
