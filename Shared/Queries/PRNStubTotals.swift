import Foundation
import SwiftData

/// One PRN product's row summary for the watch PRN list.
public struct PRNRowSummary: Sendable, Hashable, Identifiable {
  public let medicationID: UUID
  public let displayName: String
  public let summaryText: String

  public var id: UUID {
    medicationID
  }

  public init(medicationID: UUID, displayName: String, summaryText: String) {
    self.medicationID = medicationID
    self.displayName = displayName
    self.summaryText = summaryText
  }
}

/// Tracer-code stub for PRN running totals: always reports zero. Real per-ingredient
/// totals (today's logged doses, mg consumed) replace `summaryText` in
/// EPIC_05_ISSUE_02 — this seam keeps the watch PRN list wired end-to-end meanwhile.
@MainActor
public enum PRNStubTotals {
  static let stubSummaryText = "0 mg today · no doses logged"

  /// The stub summary for a single PRN product.
  public static func summary(for medication: Medication) -> PRNRowSummary {
    PRNRowSummary(
      medicationID: medication.id,
      displayName: medication.displayName,
      summaryText: stubSummaryText
    )
  }

  /// Stub summaries for every non-archived PRN product. The `kind` filter runs in
  /// memory (as elsewhere in the codebase) to avoid #Predicate enum pitfalls.
  public static func summaries(in context: ModelContext) throws -> [PRNRowSummary] {
    try context
      .fetch(FetchDescriptor<Medication>(predicate: #Predicate { !$0.isArchived }))
      .filter { $0.kind == .prn }
      .sorted { $0.displayName < $1.displayName }
      .map(summary(for:))
  }
}
