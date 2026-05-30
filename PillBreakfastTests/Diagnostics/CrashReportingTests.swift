import Foundation
@testable import PillBreakfast
import Testing

struct CrashReportingTests {
  /// Sandbox each test in its own temp subdirectory so writes don't collide
  /// across runs and so the on-disk artifacts can be inspected if a test fails.
  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("CrashReportingTests-\(UUID().uuidString)", isDirectory: true)
  }

  // MARK: - construction smoke

  @Test func instanceCanBeConstructedWithoutCrashing() {
    _ = CrashReporting()
    _ = CrashReporting(directory: temporaryDirectory())
  }

  // MARK: - persist

  @Test func persistWritesOneFilePerPayload() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let payloads = [
      Data("first".utf8),
      Data("second".utf8),
      Data("third".utf8),
    ]

    try CrashReporting.persist(payloads: payloads, kind: "diagnostic", in: directory)

    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(contents.count == 3)
    #expect(contents.allSatisfy { $0.hasSuffix(".json") })
    #expect(contents.allSatisfy { $0.hasPrefix("diagnostic-") })
  }

  @Test func persistEmbedsTimestampInFilename() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    // Fixed reference date so the embedded stamp is deterministic.
    let stamp = Date(timeIntervalSince1970: 1_750_000_000)
    let payload = Data("payload".utf8)

    try CrashReporting.persist(payloads: [payload], kind: "metric", in: directory, now: stamp)

    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    let filename = try #require(contents.first)
    #expect(filename.contains("\(Int(stamp.timeIntervalSince1970))"))
    #expect(filename.hasPrefix("metric-"))
  }

  @Test func persistRoundTripsPayloadBytes() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let payload = Data("hello world".utf8)

    try CrashReporting.persist(payloads: [payload], kind: "metric", in: directory)

    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    let filename = try #require(contents.first)
    let written = try Data(contentsOf: directory.appendingPathComponent(filename))
    #expect(written == payload)
  }

  @Test func persistIsNoOpForEmptyPayloadList() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    // No payloads means no directory creation either — important so a no-op
    // run doesn't litter `Diagnostics/` on every launch.
    try CrashReporting.persist(payloads: [], kind: "metric", in: directory)

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func persistCreatesDirectoryIfMissing() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    #expect(!FileManager.default.fileExists(atPath: directory.path))

    try CrashReporting.persist(payloads: [Data("x".utf8)], kind: "metric", in: directory)

    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
  }
}
