@testable import PillBreakfast
import Testing

struct HealthKitImportTests {
  @Test func importMedicationsReturnsTheComingSoonStub() async {
    let service = HealthKitImportService()
    #expect(await service.importMedications() == .comingSoon)
  }

  @MainActor
  @Test func sheetConstructs() {
    // Smoke: the stub sheet builds and constructs (it routes through the service so
    // EPIC_07_ISSUE_02 can replace the body without rewiring the entry point).
    _ = HealthKitImportSheet()
  }
}
