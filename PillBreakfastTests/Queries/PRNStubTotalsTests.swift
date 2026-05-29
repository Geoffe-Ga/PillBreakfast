import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct PRNStubTotalsTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func summarizesActivePRNProductsOnly() throws {
    let context = try makeContext()
    let prn = Medication(displayName: "Tylenol", unitForm: .tablet, kind: .prn)
    context.insert(prn)
    context.insert(Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance))
    context.insert(Medication(displayName: "Old PRN", unitForm: .tablet, kind: .prn, isArchived: true))
    try context.save()

    let summaries = try PRNStubTotals.summaries(in: context)
    #expect(summaries.count == 1)
    let row = try #require(summaries.first)
    #expect(row.medicationID == prn.id)
    #expect(row.displayName == "Tylenol")
    #expect(row.summaryText == PRNStubTotals.stubSummaryText)
  }

  @Test func emptyWhenNoPRNProducts() throws {
    let context = try makeContext()
    context.insert(Medication(displayName: "Vitamin D", unitForm: .capsule, kind: .maintenance))
    try context.save()

    #expect(try PRNStubTotals.summaries(in: context).isEmpty)
  }
}
