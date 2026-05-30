import Foundation
@testable import PillBreakfast
import Testing

struct MgFormatterTests {
  @Test func formatRoundsIntegerMilligrams() {
    #expect(MgFormatter.format(0) == "0 mg")
    #expect(MgFormatter.format(200) == "200 mg")
    #expect(MgFormatter.format(199.4) == "199 mg")
    #expect(MgFormatter.format(199.6) == "200 mg")
    // Lithium ceiling — the call-site precision target on the upper end.
    #expect(MgFormatter.format(2400) == "2400 mg")
  }

  @Test func formatRendersSubMilligramDosesWithDecimals() {
    // Levothyroxine ships as 25 / 50 / 100 / 200 mcg → 0.025–0.2 mg. Integer
    // truncation would render every one as "0 mg" and mis-inform a doctor.
    #expect(MgFormatter.format(0.025) == "0.025 mg")
    #expect(MgFormatter.format(0.2) == "0.200 mg")
    #expect(MgFormatter.format(0.001) == "0.001 mg")
  }

  @Test func formatGuardsAgainstNonFiniteInputs() {
    // `Int(Double.nan)` and `Int(Double.infinity)` trap at runtime; the
    // guard turns them into a legible placeholder instead.
    #expect(MgFormatter.format(.nan) == "— mg")
    #expect(MgFormatter.format(.infinity) == "— mg")
    #expect(MgFormatter.format(-.infinity) == "— mg")
  }

  @Test func formatPreservesCleanZero() {
    // 0.magnitude < 1 would otherwise route through the decimal branch and
    // produce a noisy "0.000 mg".
    #expect(MgFormatter.format(0) == "0 mg")
  }
}
