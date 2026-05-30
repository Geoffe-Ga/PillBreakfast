import Foundation

/// Renders milligram totals for the History tab drill-down and the doctor
/// export PDF. Single source of truth so the two surfaces don't drift.
///
/// - Integer-rounded for ≥ 1 mg (e.g. 2400 mg/day Lithium).
/// - Three decimal places below 1 mg so sub-mg products like levothyroxine
///   (typically 0.025–0.2 mg) don't truncate to "0 mg".
/// - A clean integer zero stays as "0 mg" rather than the noisy "0.000 mg".
/// - Guards against non-finite inputs that would otherwise trap the
///   `Int(...)` cast.
/// `nonisolated` is load-bearing here: the project sets default-MainActor
/// isolation, so without this annotation `format` becomes MainActor-isolated
/// and call sites from any non-MainActor context (Swift Testing's default,
/// the PDF renderer's potential future detach) fail to compile.
public nonisolated enum MgFormatter {
  public static func format(_ mg: Double) -> String {
    guard mg.isFinite else { return "— mg" }
    if mg == 0 || mg.magnitude >= 1 {
      return "\(Int(mg.rounded())) mg"
    }
    return String(format: "%.3f mg", mg)
  }
}
