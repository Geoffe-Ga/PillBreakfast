import Foundation
import SwiftData

@Model
public final class Ingredient {
  @Attribute(.unique) public var id: UUID
  public var name: String // "Acetaminophen"
  public var aliases: [String] // ["Paracetamol", "APAP"] — for import matching
  public var isHighRisk: Bool // requires press-and-hold confirm on any product containing it

  // Safety thresholds live HERE, not on the product.
  // User-configurable. Defaults are suggestions, not medical advice.
  public var dailyCeilingMg: Double? // e.g., 4000 for acetaminophen
  public var minIntervalMinutes: Int? // e.g., 240 = 4hr spacing

  public init(
    id: UUID = UUID(),
    name: String,
    aliases: [String] = [],
    isHighRisk: Bool = false,
    dailyCeilingMg: Double? = nil,
    minIntervalMinutes: Int? = nil
  ) {
    self.id = id
    self.name = name
    self.aliases = aliases
    self.isHighRisk = isHighRisk
    self.dailyCeilingMg = dailyCeilingMg
    self.minIntervalMinutes = minIntervalMinutes
  }
}
