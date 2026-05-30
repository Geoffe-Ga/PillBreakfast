import Foundation

/// Renders milligram totals for the History tab drill-down and the doctor
/// export PDF. Single source of truth so the two surfaces don't drift.
///
/// - Integer-rounded for ≥ 1 mg (e.g. 2400 mg/day Lithium).
/// - Below 1 mg, up to 3 decimal places, with trailing zeros stripped so
///   sub-mg products like levothyroxine read as `"0.2 mg"` (matching the
///   prescription label) rather than `"0.200 mg"`.
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
    // Negative totals can't arise from real SwiftData rows (mg accumulates
    // from `LoggedIngredientAmount.totalMg` which is always non-negative),
    // but a guard closes the "-2 mg" surface in case the contract ever slips.
    guard mg >= 0 else { return "— mg" }
    if mg == 0 || mg.magnitude >= 1 {
      return "\(Int(mg.rounded())) mg"
    }
    var rendered = String(format: "%.3f", mg)
    while rendered.hasSuffix("0") {
      rendered.removeLast()
    }
    if rendered.hasSuffix(".") {
      rendered.removeLast()
    }
    return "\(rendered) mg"
  }
}
