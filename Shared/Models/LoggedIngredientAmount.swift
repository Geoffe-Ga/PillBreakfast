import Foundation

public struct LoggedIngredientAmount: Codable, Sendable, Hashable {
  public var ingredientID: UUID
  public var ingredientName: String
  public var totalMg: Double

  public init(ingredientID: UUID, ingredientName: String, totalMg: Double) {
    self.ingredientID = ingredientID
    self.ingredientName = ingredientName
    self.totalMg = totalMg
  }
}
