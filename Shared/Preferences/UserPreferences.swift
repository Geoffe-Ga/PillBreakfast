import Foundation

/// App-wide user preferences synced iPhone → watch on the `RegimenSnapshot`
/// channel. A single small value type (App Group `UserDefaults`-backed), kept
/// out of SwiftData deliberately.
public struct UserPreferences: Codable, Sendable, Hashable {
  /// SPEC §2.1 cites 0.5s as the press-and-hold example.
  public static let defaultHoldDuration: TimeInterval = 0.5
  public static let holdDurationRange: ClosedRange<TimeInterval> = 0.3 ... 2.0

  /// Allowed snooze offsets (minutes) for the watch picker's initial position
  /// (SPEC §6.3). A discrete set, not a range — invalid values snap to the default.
  public static let allowedSnoozeOffsets: [Int] = [15, 30, 45, 60, 90]
  public static let defaultSnoozeOffsetMinutes = 30

  /// Always kept within `holdDurationRange` — clamped on construction, decode,
  /// and every assignment (`didSet`), so an out-of-range value can never reach
  /// the gesture regardless of how it arrived (UI, old snapshot, garbled wire).
  public var highRiskHoldDurationSeconds: TimeInterval {
    didSet {
      let clamped = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
      if clamped != highRiskHoldDurationSeconds { highRiskHoldDurationSeconds = clamped }
    }
  }

  /// Initial position of the watch snooze picker. Snapped to an allowed value on
  /// construction, decode, and assignment, mirroring the hold-duration guard so a
  /// garbled wire value or stale snapshot can't seat the picker on an off-menu offset.
  public var defaultSnoozeOffsetMinutes: Int {
    didSet {
      if !Self.allowedSnoozeOffsets.contains(defaultSnoozeOffsetMinutes) {
        defaultSnoozeOffsetMinutes = Self.defaultSnoozeOffsetMinutes
      }
    }
  }

  /// One-shot flag — flips to `true` when the first-launch Pill Meals
  /// onboarding sheet is dismissed (skipped or saved), so the sheet never
  /// re-appears for the same install (SPEC §8.1).
  public var pillMealsOnboarded: Bool

  public init(
    highRiskHoldDurationSeconds: TimeInterval = Self.defaultHoldDuration,
    defaultSnoozeOffsetMinutes: Int = Self.defaultSnoozeOffsetMinutes,
    pillMealsOnboarded: Bool = false
  ) {
    // didSet doesn't fire during init, so validate explicitly here.
    self.highRiskHoldDurationSeconds = highRiskHoldDurationSeconds.clamped(to: Self.holdDurationRange)
    self.defaultSnoozeOffsetMinutes = Self.allowedSnoozeOffsets.contains(defaultSnoozeOffsetMinutes)
      ? defaultSnoozeOffsetMinutes
      : Self.defaultSnoozeOffsetMinutes
    self.pillMealsOnboarded = pillMealsOnboarded
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let raw = try container.decode(TimeInterval.self, forKey: .highRiskHoldDurationSeconds)
    self.highRiskHoldDurationSeconds = raw.clamped(to: Self.holdDurationRange)
    // v2 snapshots have no `defaultSnoozeOffsetMinutes` key — default to 30 (SPEC §6.3).
    let offset = try container.decodeIfPresent(Int.self, forKey: .defaultSnoozeOffsetMinutes)
      ?? Self.defaultSnoozeOffsetMinutes
    self.defaultSnoozeOffsetMinutes = Self.allowedSnoozeOffsets.contains(offset) ? offset : Self.defaultSnoozeOffsetMinutes
    // Pre-#195 snapshots have no `pillMealsOnboarded` key — default `false`
    // so existing installs see the suggestion sheet on next launch.
    self.pillMealsOnboarded = try container.decodeIfPresent(Bool.self, forKey: .pillMealsOnboarded) ?? false
  }
}

/// Scoped to this file: a module-wide `Comparable.clamped` would land on every
/// Comparable for all of Shared's consumers and risk shadowing/ambiguity if the
/// stdlib ever adds its own. `UserPreferences` is the only caller.
private extension Comparable {
  /// Confines a value to `range`, returning the nearest bound when outside it.
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
