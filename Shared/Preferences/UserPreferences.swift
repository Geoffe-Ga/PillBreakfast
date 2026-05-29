import Foundation

/// App-wide user preferences synced iPhone → watch on the `RegimenSnapshot`
/// channel. A single small value type (App Group `UserDefaults`-backed), kept
/// out of SwiftData deliberately.
public struct UserPreferences: Codable, Sendable, Hashable {
  /// SPEC §2.1 cites 0.5s as the press-and-hold example.
  public static let defaultHoldDuration: TimeInterval = 0.5
  public static let holdDurationRange: ClosedRange<TimeInterval> = 0.3 ... 2.0

  /// Always kept within `holdDurationRange` — clamped on construction, decode,
  /// and every assignment (`didSet`), so an out-of-range value can never reach
  /// the gesture regardless of how it arrived (UI, old snapshot, garbled wire).
  public var highRiskHoldDurationSeconds: TimeInterval {
    didSet {
      let clamped = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
      if clamped != highRiskHoldDurationSeconds { highRiskHoldDurationSeconds = clamped }
    }
  }

  public init(highRiskHoldDurationSeconds: TimeInterval = Self.defaultHoldDuration) {
    // didSet doesn't fire during init, so clamp explicitly here.
    self.highRiskHoldDurationSeconds = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try container.decode(TimeInterval.self, forKey: .highRiskHoldDurationSeconds)
    self.highRiskHoldDurationSeconds = raw.clamped(to: Self.holdDurationRange)
  }
}

extension Comparable {
  /// Confines a value to `range`, returning the nearest bound when outside it.
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
