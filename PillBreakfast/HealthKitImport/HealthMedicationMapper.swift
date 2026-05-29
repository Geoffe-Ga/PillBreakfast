import Foundation

/// Pure transformation layer between a queried Health medication
/// (`HealthMedicationDraft`) and the staged form (`MedicationDraft`) that the
/// confirmation step consumes. Touches no model context — persistence happens
/// after the user confirms components.
enum HealthMedicationMapper {
  /// Carries identity (name + Health concept token) forward. Schedule and
  /// components are deliberately *not* pre-filled: iOS 26 HealthKit exposes
  /// neither dose times (see #45 / SPEC §3.1) nor ingredient composition
  /// (SPEC §6.1 — "Health doesn't expose composition reliably"), so the user
  /// supplies both after import.
  static func toDraft(_ healthDraft: HealthMedicationDraft) -> MedicationDraft {
    MedicationDraft(
      displayName: healthDraft.displayName,
      healthKitConceptID: healthDraft.healthKitConceptID
    )
  }

  /// Predicate the import sheet uses to flag a Health draft as already
  /// present in the local store. Dedupe key is the Health concept token
  /// (`healthKitConceptID`), not the display name — a user renaming a
  /// medication in Health must not cause a second copy on the PillBreakfast
  /// side, and a name collision between two unrelated Health medications must
  /// not silently overwrite either. There is no merge: a med whose token is
  /// already present is presented as read-only in the import list and is
  /// dropped from `medicationDrafts(...)` for defense-in-depth (SPEC §10
  /// Phase 6 gate; EPIC 07 ISSUE 05).
  static func isAlreadyImported(
    _ draft: HealthMedicationDraft,
    existingConceptIDs: Set<String>
  ) -> Bool {
    existingConceptIDs.contains(draft.healthKitConceptID)
  }

  /// Case-folded substring match of the draft's display name against each
  /// library ingredient's canonical name and aliases. Best signal when the
  /// Health name is the generic ("Ibuprofen" → seeded `Ibuprofen`); branded
  /// names ("Tylenol Extra Strength") typically don't auto-match and the user
  /// picks or adds the ingredient by hand.
  ///
  /// Returns the *first* match in `library` order, so callers should pre-sort
  /// by `name` for a deterministic result.
  static func suggestedIngredient(for draft: MedicationDraft, in library: [Ingredient]) -> Ingredient? {
    let needle = draft.displayName.lowercased()
    return library.first { ingredient in
      ([ingredient.name] + ingredient.aliases).contains { name in
        needle.contains(name.lowercased())
      }
    }
  }
}
