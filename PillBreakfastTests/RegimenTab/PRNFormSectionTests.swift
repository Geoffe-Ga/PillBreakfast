@testable import PillBreakfast
import Testing

@MainActor
struct PRNFormSectionTests {
  // Smoke: the PRN config section constructs against a fresh form state. Field
  // editing is exercised through MedicationFormState; save semantics arrive in
  // EPIC_05_ISSUE_06.
  @Test func constructs() {
    _ = PRNFormSection(formState: MedicationFormState())
  }
}
