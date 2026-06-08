import Foundation
import os
import SwiftData

/// Errors a single-tap log can surface.
public enum LogIntentError: Error, LocalizedError, Sendable {
  case invalidMedicationID
  case medicationNotFound(UUID)
  case highRiskForbidden
  case safetyViolation([Violation])

  public var errorDescription: String? {
    switch self {
    case .invalidMedicationID: "The dose link was malformed."
    case let .medicationNotFound(id): "That medication (\(id)) was not found."
    case .highRiskForbidden: "High-risk medications must be confirmed on the watch."
    case .safetyViolation: "Logging this dose would cross a safety limit."
    }
  }
}

public enum LogOutcome: Sendable {
  case logged
  case alreadyLogged
}

/// Shared, CI-testable core of the single-tap log. The widget's `AppIntent` is a
/// thin wrapper over this, so the safety logic — especially the high-risk refusal
/// — stays covered by the iOS test suite even though the intent lives in the
/// widget extension (which has no test target).
public enum LogNextDoseService {
  private static let logger = Logger(subsystem: "com.creekmasons.pillbreakfast", category: "LogIntent")

  /// Logs the spec'd dose unless it's high-risk (forbidden), missing/archived, or
  /// no longer pending (already logged → no-op). `@MainActor` for the isolated
  /// SwiftData / safety callees. Writes through the passed context only — never
  /// `PersistenceController.shared` (which would run the seeder).
  @MainActor
  @discardableResult
  public static func log(_ spec: NextDoseSpec, in context: ModelContext, at now: Date = .now) throws -> LogOutcome {
    let id = spec.medicationID
    let medication = try context.fetch(
      FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })
    ).first
    guard let medication, !medication.isArchived else {
      throw LogIntentError.medicationNotFound(id)
    }
    // Defense-in-depth: the widget never shows a one-tap button for a high-risk
    // group, but refuse here too so no caller can ever one-tap a high-risk dose.
    guard !medication.isHighRisk else {
      throw LogIntentError.highRiskForbidden
    }
    // Re-check at tap time: if the dose is no longer pending (already logged),
    // succeed as a no-op rather than double-logging.
    // TODO(#51 follow-up): PendingQueueSelector's ±60-min window means a tap >60
    // min after the scheduled time also returns .alreadyLogged even if it was
    // never logged. A future `.windowExpired` outcome should let the widget say
    // "log window has passed — open the app to log manually".
    let pending = try PendingQueueSelector().pendingDoses(at: now, in: context)
    guard pending.contains(where: { $0.medicationID == id }) else {
      return .alreadyLogged
    }
    // Safety is best-effort in a widget — there's no interstitial to override, so
    // log a warning and proceed (v1 policy).
    if let violations = try? SafetyEvaluator.violationsIfTaken(medication, quantity: spec.quantity, at: now, in: context),
       !violations.isEmpty
    {
      // `.private`: a medication name is PHI — redacted in non-development builds.
      logger.warning("One-tap log of \(spec.medicationName, privacy: .private) crosses \(violations.count) safety limit(s); proceeding (no widget override surface).")
    }
    try DoseEventWriter.writeDoseEvent(
      for: medication,
      scheduledFor: spec.scheduledFor,
      quantity: spec.quantity,
      status: .taken,
      // TODO(#51 follow-up): add LogSource.watchWidget so widget taps are
      // distinguishable from watch-app taps in history/analytics (raw String
      // enum → additive, no migration). `.watch` is the closest case today.
      loggedOn: .watch,
      at: now,
      in: context
    )
    return .logged
  }
}
