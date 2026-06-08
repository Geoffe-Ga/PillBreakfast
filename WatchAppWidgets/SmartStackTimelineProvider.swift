import Foundation
import os
import SwiftData
import WidgetKit

/// One Smart Stack sample: a dose group (or `nil` when idle) plus the relevance
/// metadata that floats the widget up the stack ~15 min before the dose.
nonisolated struct SmartStackEntry: TimelineEntry {
  let date: Date
  let doseGroup: SmartStackPlan.DoseGroupSummary?
  /// Stored as primitives (not `TimelineEntryRelevance`, which isn't `Sendable`)
  /// so the entry stays `Sendable`; `relevance` rebuilds it on demand.
  let relevanceScore: Float?
  let relevanceDuration: TimeInterval

  var relevance: TimelineEntryRelevance? {
    relevanceScore.map { TimelineEntryRelevance(score: $0, duration: relevanceDuration) }
  }

  static func idle(at date: Date) -> SmartStackEntry {
    SmartStackEntry(date: date, doseGroup: nil, relevanceScore: nil, relevanceDuration: 0)
  }
}

/// Smart Stack provider. Same read-only / main-actor-hop contract as the
/// complication provider (#215): `PendingQueueSelector`-adjacent reads are
/// main-actor-isolated, so the nonisolated callbacks compute the Sendable entry
/// list inside `assumeIsolated` and call `completion` outside.
nonisolated struct SmartStackTimelineProvider: TimelineProvider {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "SmartStack")
  private static let lookahead: TimeInterval = 24 * 60 * 60

  func placeholder(in context: Context) -> SmartStackEntry {
    .idle(at: .now)
  }

  func getSnapshot(in context: Context, completion: @escaping (SmartStackEntry) -> Void) {
    if context.isPreview {
      completion(.idle(at: .now))
      return
    }
    let entries = MainActor.assumeIsolated { Self.entries(at: .now) }
    completion(entries.first ?? .idle(at: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SmartStackEntry>) -> Void) {
    let entries = MainActor.assumeIsolated { Self.entries(at: .now) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  /// A leading idle entry plus three per dose group over the next 24 h:
  /// T−15 (high relevance — surfaces the stack), T (medium), T+60 (idle). Never
  /// empty; degrades to a single idle entry on any read error. Read-only.
  @MainActor
  static func entries(at now: Date) -> [SmartStackEntry] {
    do {
      let context = try makeContext()
      let meds = try activeMaintenance(in: context)
      let groups = upcomingGroups(forMeds: meds, from: now, calendar: .current)

      var entries: [SmartStackEntry] = [.idle(at: now)]
      for group in groups {
        let scheduled = group.scheduledAt
        let lead = scheduled.addingTimeInterval(-15 * 60)
        if lead > now {
          entries.append(SmartStackEntry(date: lead, doseGroup: group, relevanceScore: 10, relevanceDuration: 15 * 60))
        }
        if scheduled > now {
          entries.append(SmartStackEntry(date: scheduled, doseGroup: group, relevanceScore: 8, relevanceDuration: 60 * 60))
        }
        let tail = scheduled.addingTimeInterval(60 * 60)
        if tail > now {
          entries.append(.idle(at: tail))
        }
      }
      return entries.sorted { $0.date < $1.date }
    } catch {
      logger.error("Smart Stack timeline build failed: \(error.localizedDescription, privacy: .public)")
      return [.idle(at: now)]
    }
  }

  /// Groups across today + tomorrow so the 24 h lookahead spans the day boundary,
  /// clipped to the horizon.
  @MainActor
  private static func upcomingGroups(
    forMeds meds: [Medication],
    from now: Date,
    calendar: Calendar
  ) -> [SmartStackPlan.DoseGroupSummary] {
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
    let horizon = now.addingTimeInterval(lookahead)
    let groups = SmartStackPlan.doseGroups(maintenanceMeds: meds, on: now, calendar: calendar)
      + SmartStackPlan.doseGroups(maintenanceMeds: meds, on: tomorrow, calendar: calendar)
    return groups.filter { $0.scheduledAt <= horizon }
  }

  @MainActor
  private static func activeMaintenance(in context: ModelContext) throws -> [Medication] {
    try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .maintenance }
  }

  /// Read-only App Group container — never `PersistenceController.shared` (which
  /// runs the seeder). `@MainActor` because the App Group statics are isolated.
  @MainActor
  private static func makeContext() throws -> ModelContext {
    let configuration = ModelConfiguration(url: PersistenceController.appGroupStoreURL)
    let container = try ModelContainer(for: PersistenceController.schema, configurations: configuration)
    return ModelContext(container)
  }
}
