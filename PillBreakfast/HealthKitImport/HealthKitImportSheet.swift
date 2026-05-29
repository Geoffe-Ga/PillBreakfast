import os
import SwiftData
import SwiftUI
import UIKit

/// What the import sheet shows once authorization resolves and (when granted) the
/// one-shot medication query returns.
///
/// A top-level (nonisolated-intent) type: nesting it inside the `@MainActor`
/// `HealthKitImportSheet` would make its synthesized `Equatable` conformance
/// MainActor-isolated, which the codebase's default-MainActor isolation tolerates
/// for main-actor use but the tests pin via `@MainActor`.
enum HealthKitImportViewState: Equatable {
  case checking
  case loaded([HealthMedicationDraft])
  case denied
  case notAvailable
  case failed(String)

  /// Drives the full flow: request per-medication read scope, and on success run
  /// the one-shot query. Any thrown error (auth or fetch) folds into `.failed`
  /// and is surfaced to the user — never swallowed.
  static func resolve(using importer: any HealthKitImporting) async -> Self {
    do {
      switch try await importer.requestPerMedicationReadAuthorization() {
      case .authorized: return try await .loaded(importer.fetchUserAnnotatedMedications())
      case .denied: return .denied
      case .notAvailable: return .notAvailable
      }
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  /// Message for the states rendered as a centered prompt (everything except a
  /// non-empty `.loaded`, which renders the selection list instead).
  var message: String {
    switch self {
    case .checking:
      "Checking Apple Health…"
    case let .loaded(drafts):
      drafts.isEmpty
        ? "No medications found in Apple Health. Add them in the Health app first, or add medications to PillBreakfast by hand."
        : ""
    case .denied:
      "PillBreakfast can't see any Health medications yet. To choose which to share, open Settings ▸ Privacy & Security ▸ Health ▸ PillBreakfast."
    case .notAvailable:
      "Apple Health isn't available on this device, so there's nothing to import. You can still add medications by hand."
    case let .failed(reason):
      "Couldn't reach Apple Health: \(reason). Try again, or add medications by hand."
    }
  }

  var symbolName: String {
    switch self {
    case .checking: "heart.text.square"
    case let .loaded(drafts): drafts.isEmpty ? "tray" : "heart.text.square"
    case .denied, .notAvailable, .failed: "heart.slash"
    }
  }
}

/// "Import from Apple Health" sheet (SPEC §6.1). Requests per-medication read
/// scope, lists the granted medications with per-row selection, and on Import
/// pushes the chosen drafts onto the ingredient-confirmation step
/// (`ConfirmComponentsView`), which persists the medications and pushes the
/// snapshot to the watch.
struct HealthKitImportSheet: View {
  /// Shown as the read-only assurance footer; also asserted in tests so the trust
  /// signal can't be silently deleted.
  static let readOnlyDisclaimer = "PillBreakfast only reads from Apple Health; it never writes."

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "HealthImport"
  )

  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext

  // @State (not let) so the injected importer survives SwiftUI redraws; the
  // default is the live service, tests inject a fake via the initializer.
  @State private var importer: any HealthKitImporting
  @State private var state: HealthKitImportViewState = .checking
  @State private var selectedIDs: Set<UUID> = []
  /// Health concept tokens already on a local `Medication`. Loaded once when
  /// the sheet appears so re-running the import flow against the same Health
  /// authorization shows those rows as "Already imported" and skips them at
  /// projection time (SPEC §10 Phase 6 gate).
  @State private var existingConceptIDs: Set<String> = []
  @State private var path = NavigationPath()

  init(importer: any HealthKitImporting = HealthKitImportService()) {
    _importer = State(initialValue: importer)
  }

  /// Pure mapping used by the Import button: pick the selected entries from the
  /// loaded drafts and project them into `MedicationDraft`s. Drafts whose
  /// `healthKitConceptID` already lives on a local `Medication` are dropped
  /// here as well as visually disabled in the row — belt-and-suspenders against
  /// a bug-introduced selection ever reaching persistence. Exposed `static` so
  /// tests can verify the selection→draft transform without the view layer.
  static func medicationDrafts(
    from loaded: [HealthMedicationDraft],
    selectedIDs: Set<UUID>,
    existingConceptIDs: Set<String> = []
  ) -> [MedicationDraft] {
    loaded
      .filter { selectedIDs.contains($0.id) }
      .filter { !HealthMedicationMapper.isAlreadyImported($0, existingConceptIDs: existingConceptIDs) }
      .map(HealthMedicationMapper.toDraft)
  }

  /// One-shot read of the Health concept tokens already linked to local
  /// `Medication`s. The predicate filters in the store so manual (non-Health)
  /// meds are never materialized. Returns an empty set on a thrown fetch so
  /// the sheet still presents the import list rather than going dark — note
  /// that with an empty set the mapper's `isAlreadyImported` is `false` for
  /// every draft, so a disk-full or schema-mismatch error restores pre-PR
  /// behavior (duplicates possible) rather than silently blocking import. The
  /// failure is logged via OSLog so it still leaves a trace.
  static func fetchExistingConceptIDs(from context: ModelContext) -> Set<String> {
    let descriptor = FetchDescriptor<Medication>(
      predicate: #Predicate { $0.healthKitConceptID != nil }
    )
    do {
      let medications = try context.fetch(descriptor)
      return Set(medications.compactMap(\.healthKitConceptID))
    } catch {
      // Explicit `.private` — SwiftData error descriptions can embed model
      // summaries that include medication names (PHI). String interpolation
      // defaults to `.auto`, which redacts in release but is implicit; pin it
      // so the intent survives future refactors.
      logger.error(
        "Health import dedupe fetch failed: \(error.localizedDescription, privacy: .private)"
      )
      return []
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      content
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
          }
          if case let .loaded(drafts) = state, !drafts.isEmpty {
            ToolbarItem(placement: .confirmationAction) {
              Button("Next") { confirm(drafts) }
                .disabled(selectedIDs.isEmpty)
            }
          }
        }
        .navigationDestination(for: ConfirmComponentsRoute.self) { route in
          ConfirmComponentsView(drafts: route.drafts) { dismiss() }
        }
        .task {
          existingConceptIDs = Self.fetchExistingConceptIDs(from: modelContext)
          state = await HealthKitImportViewState.resolve(using: importer)
        }
    }
  }

  @ViewBuilder private var content: some View {
    switch state {
    case let .loaded(drafts) where !drafts.isEmpty:
      medicationList(drafts)
    default:
      messageView
    }
  }

  private func medicationList(_ drafts: [HealthMedicationDraft]) -> some View {
    List {
      Section {
        ForEach(drafts) { draft in
          let alreadyImported = HealthMedicationMapper.isAlreadyImported(
            draft, existingConceptIDs: existingConceptIDs
          )
          Button { toggle(draft.id) } label: { row(draft, alreadyImported: alreadyImported) }
            .buttonStyle(.plain)
            .disabled(alreadyImported)
            .accessibilityHint(alreadyImported ? "Already in your PillBreakfast regimen." : "")
        }
      } footer: {
        Text(Self.readOnlyDisclaimer)
      }
    }
  }

  private func row(_ draft: HealthMedicationDraft, alreadyImported: Bool) -> some View {
    let isSelected = selectedIDs.contains(draft.id)
    return HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(draft.displayName)
        Text(alreadyImported ? "Already imported" : (draft.hasSchedule ? "Scheduled" : "As needed"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if !alreadyImported {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? .primary : .secondary)
          .accessibilityLabel(isSelected ? "Selected for import" : "Not selected")
      }
    }
    .contentShape(.rect)
  }

  private var messageView: some View {
    VStack(spacing: 16) {
      Image(systemName: state.symbolName)
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Import from Apple Health")
        .font(.headline)
      Text(state.message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if state == .denied {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
  }

  private func toggle(_ id: UUID) {
    if selectedIDs.contains(id) {
      selectedIDs.remove(id)
    } else {
      selectedIDs.insert(id)
    }
  }

  private func confirm(_ drafts: [HealthMedicationDraft]) {
    let projected = Self.medicationDrafts(
      from: drafts,
      selectedIDs: selectedIDs,
      existingConceptIDs: existingConceptIDs
    )
    path.append(ConfirmComponentsRoute(drafts: projected))
  }
}

#Preview {
  HealthKitImportSheet()
}
