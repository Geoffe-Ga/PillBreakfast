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

  // MARK: - prune

  /// Seed `count` files of the given kind with deterministic, lex-sortable
  /// names (`<kind>-0001-…json`, `<kind>-0002-…json`, …). The zero-padding
  /// matches `persist`'s "lex sort == chronological" invariant.
  private func seedFiles(count: Int, kind: String, in directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for index in 1 ... count {
      let filename = "\(kind)-\(String(format: "%04d", index))-AAAA.json"
      try Data().write(to: directory.appendingPathComponent(filename))
    }
  }

  @Test func pruneKeepsTheMostRecentNOfASingleKind() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try seedFiles(count: CrashReporting.retainPerKind + 5, kind: "metric", in: directory)

    CrashReporting.prune(kind: "metric", in: directory)

    let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    #expect(remaining.count == CrashReporting.retainPerKind)
    // The five lowest-numbered (oldest) files should be gone; the survivors
    // include the highest-numbered (newest) file.
    let highestIndex = CrashReporting.retainPerKind + 5
    let highestFilename = "metric-\(String(format: "%04d", highestIndex))-AAAA.json"
    #expect(remaining.contains(highestFilename))
    #expect(!remaining.contains("metric-0001-AAAA.json"))
    #expect(!remaining.contains("metric-0005-AAAA.json"))
  }

  @Test func pruneScopesToOneKindAndLeavesOthersUntouched() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try seedFiles(count: CrashReporting.retainPerKind + 3, kind: "metric", in: directory)
    try seedFiles(count: CrashReporting.retainPerKind + 7, kind: "diagnostic", in: directory)

    CrashReporting.prune(kind: "metric", in: directory)

    let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    let metric = remaining.filter { $0.hasPrefix("metric-") }
    let diagnostic = remaining.filter { $0.hasPrefix("diagnostic-") }
    #expect(metric.count == CrashReporting.retainPerKind)
    // Diagnostic bucket is untouched — prune is per-kind, so its over-budget
    // count survives until a diagnostic write triggers its own prune.
    #expect(diagnostic.count == CrashReporting.retainPerKind + 7)
  }

  @Test func pruneIsNoOpWhenUnderBudget() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try seedFiles(count: 5, kind: "metric", in: directory)

    CrashReporting.prune(kind: "metric", in: directory)

    let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(remaining.count == 5)
  }

  @Test func pruneIsNoOpForEmptyDirectory() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    CrashReporting.prune(kind: "metric", in: directory)

    let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(remaining.isEmpty)
  }

  @Test func pruneIsNoOpForMissingDirectory() {
    let directory = temporaryDirectory()
    // Directory was never created — this is the first-launch path, before
    // any payload has been written. Prune must not throw or surface noise.
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    CrashReporting.prune(kind: "metric", in: directory)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func persistTruncatesAfterEachBatchWrite() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    // Drive persist across multiple "days" so each batch carries a distinct
    // timestamp prefix and the lex-sort tie-break across batches works
    // correctly. Each batch writes 4 payloads; after enough batches the
    // metric bucket exceeds retainPerKind and persist's truncate fires.
    let payloads = Array(repeating: Data("payload".utf8), count: 4)
    let batches = (CrashReporting.retainPerKind / 4) + 2 // ~9 batches → 36 writes
    for batch in 0 ..< batches {
      // Distinct timestamps across batches; within a batch the per-file
      // UUID suffix breaks ties so all 4 of a batch's files have unique
      // names with the same stamp.
      let now = Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(batch))
      try CrashReporting.persist(payloads: payloads, kind: "metric", in: directory, now: now)
    }
    let metric = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      .filter { $0.hasPrefix("metric-") }
    #expect(metric.count == CrashReporting.retainPerKind)
  }
}
