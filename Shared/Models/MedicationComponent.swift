import Foundation
import SwiftData

@Model
public final class MedicationComponent {
  // The join table: "this product contains X mg of this ingredient per unit"
  @Attribute(.unique) public var id: UUID
  public var medication: Medication?
  public var ingredient: Ingredient?
  public var dosagePerUnitMg: Double // 500.0 = 500mg acetaminophen per Tylenol Extra Strength tablet

  public init(
    id: UUID = UUID(),
    medication: Medication? = nil,
    ingredient: Ingredient? = nil,
    dosagePerUnitMg: Double
  ) {
    self.id = id
    self.medication = medication
    self.ingredient = ingredient
    self.dosagePerUnitMg = dosagePerUnitMg
  }
}
