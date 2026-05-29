import Foundation
@testable import PillBreakfast
import SwiftData
import Testing

@MainActor
struct SnoozeRecordStoreTests {
  private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
      for: PersistenceController.schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
  }

  @Test func incrementCountsPerOccurrence() throws {
    let context = try makeContext()
    let doseID = UUID()
    let day = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context) == 1)
    #expect(try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context) == 2)
    #expect(try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context) == 3)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: doseID, on: day, in: context) == 3)
  }

  @Test func currentCountIsZeroForUntrackedOccurrence() throws {
    let context = try makeContext()
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: UUID(), on: .now, in: context) == 0)
  }

  @Test func countsAreIndependentAcrossDoses() throws {
    let context = try makeContext()
    let a = UUID()
    let b = UUID()
    let day = Date(timeIntervalSince1970: 1_700_000_000)

    try SnoozeRecordStore.increment(scheduledDoseID: a, on: day, at: day, in: context)
    try SnoozeRecordStore.increment(scheduledDoseID: a, on: day, at: day, in: context)

    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: a, on: day, in: context) == 2)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: b, on: day, in: context) == 0)
  }

  @Test func resetClearsTheCount() throws {
    let context = try makeContext()
    let doseID = UUID()
    let day = Date(timeIntervalSince1970: 1_700_000_000)
    try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context)
    try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context)

    try SnoozeRecordStore.reset(scheduledDoseID: doseID, on: day, in: context)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: doseID, on: day, in: context) == 0)
  }
}
