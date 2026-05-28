import Foundation
import SwiftData

@Model
public final class ScheduledDose {
  @Attribute(.unique) public var id: UUID

  public init(id: UUID = UUID()) {
    self.id = id
  }
}
