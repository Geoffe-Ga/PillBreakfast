public enum MedicationKind: String, Codable, Sendable, CaseIterable {
  case maintenance
  case prn
}

public enum MedicationForm: String, Codable, Sendable, CaseIterable {
  case tablet
  case capsule
  case liquid
  case other
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
