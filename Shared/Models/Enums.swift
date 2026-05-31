public enum MedicationKind: String, Codable, Sendable, CaseIterable {
  case maintenance
  case prn
}

public enum MedicationForm: String, Codable, Sendable, CaseIterable {
  case tablet
  case capsule
  case liquid
  case other

  /// User-facing unit label, e.g. "tablet" / "capsule". "other" falls back to "dose"
  /// rather than the bare rawValue so it reads naturally in the watch confirm UI.
  public var singularLabel: String {
    switch self {
    case .tablet: "tablet"
    case .capsule: "capsule"
    case .liquid: "mL"
    case .other: "dose"
    }
  }

  public var pluralLabel: String {
    switch self {
    case .tablet: "tablets"
    case .capsule: "capsules"
    case .liquid: "mL"
    case .other: "doses"
    }
  }
}

public enum DoseStatus: String, Codable, Sendable, CaseIterable {
  case taken
  case skipped
  case snoozed
}

public enum LogSource: String, Codable, Sendable, CaseIterable {
  case watch
  case iphone
}
