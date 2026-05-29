import SwiftUI
import UIKit

/// What the import sheet shows once the authorization prompt resolves.
///
/// A top-level (nonisolated) type on purpose: nesting it inside the `@MainActor`
/// `HealthKitImportSheet` would make its synthesized `Equatable` conformance
/// MainActor-isolated, which Swift 6 then refuses to use from the nonisolated
/// async code (and tests) that drive the mapping.
enum HealthKitImportViewState: Equatable {
  case checking
  case authorized
  case denied
  case notAvailable
  case failed(String)

  /// Pure mapping from the typed authorization result to display state.
  static func mapped(from result: HealthKitImportAuthorizationResult) -> Self {
    switch result {
    case .authorized: .authorized
    case .denied: .denied
    case .notAvailable: .notAvailable
    }
  }

  /// Runs the request through the (possibly faked) importer and folds both the
  /// typed result and any thrown error into a single display state. A genuine
  /// error becomes `.failed` and is surfaced to the user — never swallowed.
  static func resolve(using importer: any HealthKitImporting) async -> Self {
    do {
      return try await mapped(from: importer.requestPerMedicationReadAuthorization())
    } catch {
      return .failed(error.localizedDescription)
    }
  }

  var message: String {
    switch self {
    case .checking:
      "Checking Apple Health…"
    case .authorized:
      "Access granted. PillBreakfast can read the medications you shared — importing them lands in a coming update. PillBreakfast only reads from Apple Health; it never writes."
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
    case .checking, .authorized: "heart.text.square"
    case .denied, .notAvailable, .failed: "heart.slash"
    }
  }
}

/// "Import from Apple Health" sheet (SPEC §6.1). Drives the per-medication read
/// authorization flow and branches on the outcome. Querying the granted
/// medications lands in the next issue (EPIC 07 ISSUE 03).
struct HealthKitImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  // @State (not let) so the injected importer survives SwiftUI redraws; the
  // default is the live service, tests inject a fake via the initializer.
  @State private var importer: any HealthKitImporting
  @State private var state: HealthKitImportViewState = .checking

  init(importer: any HealthKitImporting = HealthKitImportService()) {
    _importer = State(initialValue: importer)
  }

  var body: some View {
    NavigationStack {
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
      .navigationTitle("Apple Health")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .task {
        state = await HealthKitImportViewState.resolve(using: importer)
      }
    }
  }
}

#Preview {
  HealthKitImportSheet()
}
