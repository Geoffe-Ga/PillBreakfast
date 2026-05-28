@testable import PillBreakfast
import SwiftUI
import Testing

struct ColorHexTests {
  @Test func nilInputReturnsNil() {
    #expect(Color(hex: nil) == nil)
  }

  @Test func malformedInputReturnsNil() {
    #expect(Color(hex: "not-a-color") == nil)
    #expect(Color(hex: "#FFF") == nil) // 3-digit shorthand unsupported
    #expect(Color(hex: "#1234567") == nil) // too long
  }

  @Test func sixDigitHexParses() {
    #expect(Color(hex: "#FFAA00") != nil)
    #expect(Color(hex: "FFAA00") != nil) // leading # is optional
  }
}
