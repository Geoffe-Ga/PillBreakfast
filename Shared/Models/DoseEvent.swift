import Foundation
import SwiftData

@Model
public final class DoseEvent {
  @Attribute(.unique) public var id: UUID

  public init(id: UUID = UUID()) {
    self.id = id
  }
}
