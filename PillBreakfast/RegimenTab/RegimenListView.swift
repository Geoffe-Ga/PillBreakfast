import os
import SwiftData
import SwiftUI

/// Grouped regimen list (Maintenance / PRN) with add, edit, and swipe-to-archive.
/// Editing pushes the updated regimen to the watch via `WatchConnectivityCoordinator`.
struct RegimenListView: View {
  /// Hero icon size in the empty state.
  private static let emptyStateIconSize: CGFloat = 44
  /// Inter-line spacing between the medication name and its schedule summary
  /// — sub-compact on purpose so the two lines hug as one row.
  private static let rowLineSpacing: CGFloat = 2

  @Environment(\.modelContext) private var modelContext
  @Query(filter: #Predicate<Medication> { !$0.isArchived }, sort: \Medication.displayName)
  private var medications: [Medication]
  /// Tie-break on `createdAt` so two new sortOrder=0 meals don't shuffle.
  @Query(sort: [SortDescriptor(\PillMeal.sortOrder), SortDescriptor(\PillMeal.createdAt)])
  private var pillMeals: [PillMeal]
  @State private var showingAdd = false
  @State private var showingHealthKitImport = false
  @State private var archiveError: String?

  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "RegimenEdit")

  private var maintenance: [Medication] {
    medications.filter { $0.kind == .maintenance }
  }

  private var prn: [Medication] {
    medications.filter { $0.kind == .prn }
  }

  var body: some View {
    List {
      if !medications.isEmpty {
        PillMealsListSection(meals: pillMeals)
        section("Maintenance", medications: maintenance)
        section("PRN", medications: prn)
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .glassBackground()
    // `ContentUnavailableView` is a full-view replacement and ignores List
    // row sizing — wrapping it in a `Section` collapses it to row height.
    // Overlay it instead so it centres in the List's frame while the
    // toolbar (+ / Import) stays available.
    .overlay {
      if medications.isEmpty {
        ContentUnavailableView {
          Label {
            LiquidGlassTheme.Typography.display("No medications yet")
          } icon: {
            Image(systemName: "pills.fill")
              .font(.system(size: Self.emptyStateIconSize, weight: .light))
              .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          }
        } description: {
          LiquidGlassTheme.Typography.footnote("Add a medication to start tracking, or import what's already in Apple Health.")
            .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
            .multilineTextAlignment(.center)
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingAdd = true
        } label: {
          Label("Add medication", systemImage: "plus")
        }
      }
      ToolbarItem(placement: .secondaryAction) {
        Button {
          showingHealthKitImport = true
        } label: {
          Label("Import from Apple Health", systemImage: "heart.text.square")
        }
      }
    }
    .sheet(isPresented: $showingAdd) {
      AddMedicationView()
    }
    .sheet(isPresented: $showingHealthKitImport) {
      HealthKitImportSheet()
    }
    .alert(
      "Couldn't archive medication",
      isPresented: Binding(get: { archiveError != nil }, set: { if !$0 { archiveError = nil } })
    ) {
      Button("OK", role: .cancel) { archiveError = nil }
    } message: {
      Text(archiveError ?? "")
    }
  }

  @ViewBuilder
  private func section(_ title: String, medications: [Medication]) -> some View {
    if !medications.isEmpty {
      Section {
        ForEach(medications) { medication in
          NavigationLink {
            EditMedicationView(medication: medication)
          } label: {
            row(medication)
          }
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              archive(medication)
            } label: {
              Label("Archive", systemImage: "archivebox")
            }
          }
        }
      } header: {
        LiquidGlassTheme.Typography.headline(title)
          .textCase(nil)
      }
    }
  }

  private func row(_ medication: Medication) -> some View {
    HStack(alignment: .center, spacing: LiquidGlassTheme.Spacing.compact) {
      VStack(alignment: .leading, spacing: Self.rowLineSpacing) {
        LiquidGlassTheme.Typography.medicationName(medication.displayName)
        LiquidGlassTheme.Typography.footnote(Self.scheduleSummary(for: medication))
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
      }
      Spacer(minLength: 0)
      if medication.isHighRisk {
        // Monochrome on the iPhone setup surface. CLAUDE.md reserves the
        // amber accent for press-and-hold confirmations on the watch
        // logging path; the high-risk indicator here stays glyph-only and
        // relies on the symbol shape (and accessibility label) to read.
        Image(systemName: "exclamationmark.shield.fill")
          .foregroundStyle(LiquidGlassTheme.Colors.secondaryText)
          .accessibilityLabel("High risk")
      }
    }
    // Extra vertical padding (`Spacing.compact` = 8 pt on top of the
    // `.insetGrouped` default) is deliberate — the two-line name + schedule
    // hierarchy needs breathing room not provided by the system row insets.
    .padding(.vertical, LiquidGlassTheme.Spacing.compact)
  }

  /// One-line schedule summary: "N daily dose(s)" for maintenance,
  /// "As-needed" for PRN. `internal static` so the singular/plural and
  /// zero-dose copy can be unit-tested without spinning up a SwiftUI runtime.
  static func scheduleSummary(for medication: Medication) -> String {
    switch medication.kind {
    case .maintenance:
      let count = medication.schedule.count
      if count == 0 { return "No doses scheduled" }
      return count == 1 ? "1 daily dose" : "\(count) daily doses"
    case .prn:
      return "As-needed"
    }
  }

  private func archive(_ medication: Medication) {
    medication.isArchived = true
    do {
      try modelContext.save()
    } catch {
      RegimenListView.logger.error("Failed to archive medication: \(error.localizedDescription, privacy: .public)")
      modelContext.rollback()
      archiveError = "The change couldn't be saved. Please try again."
      return
    }
    WatchConnectivityCoordinator.shared.pushRegimen(from: modelContext)
  }
}

#Preview {
  NavigationStack {
    RegimenListView()
  }
  .modelContainer(for: [Medication.self, PillMeal.self], inMemory: true)
}
