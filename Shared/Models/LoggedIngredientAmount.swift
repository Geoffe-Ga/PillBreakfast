import Foundation

/// `nonisolated` so the `Hashable`/`Equatable` conformances aren't pulled
/// onto the MainActor by the iOS target's `-default-isolation MainActor`
/// flag — this struct is a pure value type whose members are all `Sendable`
/// primitives, and it crosses the actor boundary in the detached PDF render
/// path (`PDFDayBlockSnapshot.ingredientTotals`).
public nonisolated struct LoggedIngredientAmount: Codable, Sendable, Hashable {
  public var ingredientID: UUID
  public var ingredientName: String
  public var totalMg: Double

  public init(ingredientID: UUID, ingredientName: String, totalMg: Double) {
    self.ingredientID = ingredientID
    self.ingredientName = ingredientName
    self.totalMg = totalMg
  }
}
