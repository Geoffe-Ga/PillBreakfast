import Foundation

/// Ordering + search for the iPhone Log tab's medication picker.
///
/// "Registered" (active regimen) medications come first; archived ones follow in
/// a second section so a med you've stopped can still be logged retroactively
/// without cluttering the common case. Pure and free of SwiftUI / SwiftData
/// fetching so it unit-tests without a view host.
enum LogMedicationList {
  struct Section: Identifiable {
    let id: String
    let title: String
    let medications: [Medication]
  }

  /// - Parameters:
  ///   - medications: every medication in the store (active + archived).
  ///   - query: search text; empty matches everything. Case- and
  ///     diacritic-insensitive substring match against `displayName`.
  /// - Returns: at most two sections — active ("Your medications") then archived
  ///   ("Archived") — each alphabetised, omitting any that end up empty.
  static func sections(from medications: [Medication], query: String = "") -> [Section] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    func matches(_ medication: Medication) -> Bool {
      guard !trimmed.isEmpty else { return true }
      return medication.displayName.range(
        of: trimmed,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) != nil
    }
    func sorted(_ meds: [Medication]) -> [Medication] {
      meds.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    let active = sorted(medications.filter { !$0.isArchived && matches($0) })
    let archived = sorted(medications.filter { $0.isArchived && matches($0) })

    var sections: [Section] = []
    if !active.isEmpty {
      sections.append(Section(id: "active", title: "Your medications", medications: active))
    }
    if !archived.isEmpty {
      sections.append(Section(id: "archived", title: "Archived", medications: archived))
    }
    return sections
  }
}
