import SwiftUI

public extension Color {
  /// Parses a `"#RRGGBB"` hex string; returns nil for nil/malformed input so
  /// callers can simply omit the swatch rather than render a wrong color.
  init?(hex: String?) {
    guard let hex else { return nil }
    let trimmed = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}
