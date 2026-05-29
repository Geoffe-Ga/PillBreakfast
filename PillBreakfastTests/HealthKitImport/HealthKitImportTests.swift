@testable import PillBreakfast
import Testing

struct HealthKitImportTests {
  @Test func importMedicationsReturnsTheComingSoonStub() async {
    let service = HealthKitImportService()
    #expect(await service.importMedications() == .comingSoon)
  }

  @MainActor
  @Test func sheetConstructs() {
    _ = HealthKitImportSheet()
  }
}
