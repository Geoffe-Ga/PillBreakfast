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

    #expect(try SnoozeRecordStore.increment(scheduledDoseID: a, on: day, at: day, in: context) == 1)
    #expect(try SnoozeRecordStore.increment(scheduledDoseID: a, on: day, at: day, in: context) == 2)

    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: a, on: day, in: context) == 2)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: b, on: day, in: context) == 0)
  }

  @Test func resetClearsTheCount() throws {
    let context = try makeContext()
    let doseID = UUID()
    let day = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context) == 1)
    #expect(try SnoozeRecordStore.increment(scheduledDoseID: doseID, on: day, at: day, in: context) == 2)

    try SnoozeRecordStore.reset(scheduledDoseID: doseID, on: day, in: context)
    #expect(try SnoozeRecordStore.currentCount(scheduledDoseID: doseID, on: day, in: context) == 0)
  }

  @Test func incrementPrunesRecordsOlderThanHorizon() throws {
    let context = try makeContext()
    let calendar = Calendar(identifier: .gregorian)
    let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
    let staleDay = try #require(
      calendar.date(byAdding: .day, value: -(SnoozeRecordStore.staleHorizonDays + 1), to: today)
    )
    let edgeKeptDay = try #require(
      calendar.date(byAdding: .day, value: -(SnoozeRecordStore.staleHorizonDays - 1), to: today)
    )

    // Seed two pre-existing rows, both for different occurrences.
    let staleID = UUID()
    let keptID = UUID()
    context.insert(SnoozeRecord(scheduledDoseID: staleID, calendarDay: staleDay, count: 1, lastSnoozedAt: staleDay))
    context.insert(SnoozeRecord(scheduledDoseID: keptID, calendarDay: edgeKeptDay, count: 1, lastSnoozedAt: edgeKeptDay))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<SnoozeRecord>()) == 2)

    // Today's increment fires the prune.
    #expect(
      try SnoozeRecordStore.increment(scheduledDoseID: UUID(), on: today, at: today, in: context, calendar: calendar) == 1
    )

    // Stale row is gone; the edge-kept row and today's row both remain.
    let remaining = try context.fetch(FetchDescriptor<SnoozeRecord>())
    let surviving = Set(remaining.map(\.scheduledDoseID))
    #expect(!surviving.contains(staleID))
    #expect(surviving.contains(keptID))
    #expect(remaining.count == 2)
  }
}
