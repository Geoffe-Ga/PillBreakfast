import Foundation

/// Display-ready form of a `Violation`: the at-risk ingredient's name and the
/// detail lines the warning interstitial shows. Pure presentation, so the wording
/// is unit-testable without rendering a view.
public struct ViolationMessage: Sendable, Hashable, Identifiable {
  public let id: String
  public let title: String
  public let detailLines: [String]

  public init(id: String, title: String, detailLines: [String]) {
    self.id = id
    self.title = title
    self.detailLines = detailLines
  }
}

@MainActor
public enum ViolationMessageBuilder {
  public static func message(for violation: Violation, at now: Date) -> ViolationMessage {
    switch violation {
    case let .ceiling(ingredient, current, proposed, ceiling):
      ViolationMessage(
        id: violation.id,
        title: ingredient.name,
        detailLines: [
          "Already today: \(mg(current))",
          "Would total: \(mg(proposed))",
          "Daily limit: \(mg(ceiling))",
        ]
      )
    case let .tooSoon(ingredient, lastTakenAt, minInterval):
      ViolationMessage(
        id: violation.id,
        title: ingredient.name,
        detailLines: [
          "Last dose: \(lastTakenAt.formatted(date: .omitted, time: .shortened)) (\(hoursMinutes(seconds: now.timeIntervalSince(lastTakenAt))) ago)",
          "Recommended spacing: \(hoursMinutes(minutes: minInterval))",
        ]
      )
    }
  }

  private static func mg(_ value: Double) -> String {
    "\(Int(value.rounded())) mg"
  }

  private static func hoursMinutes(seconds: TimeInterval) -> String {
    hoursMinutes(minutes: Int(seconds / 60))
  }

  /// "4h", "1h 20m", or "45m" — never an empty string (0 → "0m").
  private static func hoursMinutes(minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    if hours > 0, mins > 0 { return "\(hours)h \(mins)m" }
    if hours > 0 { return "\(hours)h" }
    return "\(mins)m"
  }
}
