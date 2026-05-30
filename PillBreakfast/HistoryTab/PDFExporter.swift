import Foundation
import os
import PDFKit
import SwiftData
import UIKit

/// Produces the 30-day medication-history PDF Geoff hands his psychiatrist
/// (SPEC §2.4 / §6.2). All work is offline — `UIGraphicsPDFRenderer` is
/// `UIKit` / `CoreGraphics`-only and never touches the network. The output
/// file lives in the user's temporary directory; the share sheet picks up
/// the URL.
///
/// The collect phase is MainActor-bound (SwiftData fetch + relationship
/// traversal); the render phase is `nonisolated` and is invoked from a
/// detached task so dense histories don't stall the UI. The MainActor /
/// background seam is `PDFDayBlockSnapshot`, a Sendable value type with
/// pre-materialized display strings.
@MainActor
enum PDFExporter {
  /// Window matches the History tab: 30 days inclusive (today + 29 prior).
  static let windowDays = 30

  /// `nonisolated` so the detached `render` can log its page count without
  /// hopping back to the MainActor. `Logger` is `Sendable`.
  private nonisolated static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "PDFExport"
  )

  /// Render the export and return the temp-directory URL. Collect runs on
  /// the MainActor (`@MainActor` callers — typically a SwiftUI `.task`);
  /// the render pass is dispatched to a detached `userInitiated` task so a
  /// dense history doesn't freeze the UI. Throws on SwiftData fetch
  /// failure, calendar-arithmetic failure, or `UIGraphicsPDFRenderer.writePDF`
  /// failure.
  static func exportLast30Days(
    from context: ModelContext,
    now: Date = .now,
    calendar: Calendar = .current,
    layout: PDFLayoutConstants = .letter
  ) async throws -> URL {
    let blocks = try collectBlocks(in: context, now: now, calendar: calendar)
    let url = temporaryURL()
    // Read the disclaimer here on the MainActor so the detached render
    // doesn't have to reach into `IngredientLibrarySeeder` (whose isolation
    // varies across targets); a `String` is `Sendable`, so it crosses the
    // detach boundary cleanly.
    let disclaimer = IngredientLibrarySeeder.disclaimer
    return try await Task.detached(priority: .userInitiated) {
      try render(blocks: blocks, layout: layout, now: now, disclaimer: disclaimer, to: url)
    }.value
  }

  // MARK: - Data collection

  /// Fetch every `DoseEvent` in the 30-day window, group them by calendar
  /// day, format each event into a Sendable row string, and roll up `.taken`
  /// event `ingredientAmounts` into per-day totals. Reads the denormalized
  /// snapshot, never the live product graph (SPEC §5.3 / CLAUDE.md).
  ///
  /// Returns `PDFDayBlockSnapshot`s — value-type projections of the live
  /// `DoseEvent` graph, safe to ship across the actor boundary to the
  /// detached renderer.
  static func collectBlocks(
    in context: ModelContext,
    now: Date,
    calendar: Calendar
  ) throws -> [PDFDayBlockSnapshot] {
    let startOfToday = calendar.startOfDay(for: now)
    guard let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: startOfToday),
          let windowEnd = calendar.date(byAdding: .day, value: 1, to: startOfToday)
    else {
      throw PDFExporterError.calendarArithmeticFailed
    }
    let descriptor = FetchDescriptor<DoseEvent>(
      predicate: #Predicate { $0.takenAt >= windowStart && $0.takenAt < windowEnd },
      sortBy: [SortDescriptor(\DoseEvent.takenAt)]
    )
    let events = try context.fetch(descriptor)
    let byDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.takenAt) }
    // Most-recent day first so the doctor opens the PDF and sees today.
    return byDay.keys.sorted(by: >).map { day in
      let dayEvents = byDay[day] ?? []
      let totals = aggregateIngredients(in: dayEvents)
      let rows = dayEvents.map { PDFEventRowSnapshot(displayLine: eventRow($0)) }
      return PDFDayBlockSnapshot(date: day, rows: rows, ingredientTotals: totals)
    }
  }

  /// Per-day ingredient roll-up: sum mg by `ingredientID`, keep the earliest
  /// snapshot's name, and sort alphabetically for stable display. Only
  /// `.taken` events contribute, matching `HistoryQueries.dailySummary`.
  ///
  /// - Precondition: `events` is sorted ascending by `takenAt`. The
  ///   "earliest-name wins" rule reads the first occurrence in the iteration
  ///   order, so an unsorted slice would silently pick the wrong name.
  ///   Enforced with `precondition` (not `assert`) — a doctor's export with
  ///   the wrong ingredient name is worse than a hard crash that surfaces
  ///   the upstream sort bug.
  static func aggregateIngredients(in events: [DoseEvent]) -> [LoggedIngredientAmount] {
    // `DoseEvent` is a `PersistentModel` class, so `==` is identity (not
    // value equality). That's what we want: `sorted` returns the same
    // instances in a possibly-reordered array, so a per-position identity
    // comparison detects unsorted input.
    precondition(
      events == events.sorted(by: { $0.takenAt < $1.takenAt }),
      "aggregateIngredients precondition: events must be sorted ascending by takenAt"
    )
    var totalsByID: [UUID: LoggedIngredientAmount] = [:]
    for event in events where event.status == .taken {
      for amount in event.ingredientAmounts {
        if let existing = totalsByID[amount.ingredientID] {
          totalsByID[amount.ingredientID] = LoggedIngredientAmount(
            ingredientID: amount.ingredientID,
            ingredientName: existing.ingredientName,
            totalMg: existing.totalMg + amount.totalMg
          )
        } else {
          totalsByID[amount.ingredientID] = amount
        }
      }
    }
    return totalsByID.values.sorted { $0.ingredientName < $1.ingredientName }
  }

  private static func temporaryURL() -> URL {
    // UUID-suffixed so repeated exports in the same second never collide
    // (and Mail's preview cache distinguishes them by URL).
    FileManager.default.temporaryDirectory
      .appending(component: "PillBreakfast-\(UUID().uuidString).pdf")
  }

  // MARK: - Row formatting (MainActor; touches the live DoseEvent graph)

  static func eventRow(_ event: DoseEvent) -> String {
    // Formats in the device's current timezone — a dose logged while
    // traveling shows in the user's current timezone, not the timezone where
    // it was taken. Acceptable for v1 (the export is a summary doctors read
    // at home); don't reflex-fix to UTC.
    let time = event.takenAt.formatted(date: .omitted, time: .shortened)
    let med = event.medication?.displayName ?? "Unknown medication"
    let qty = event.quantity == 1 ? "1 pill" : "\(event.quantity) pills"
    return "\(time)  •  \(med)  •  \(qty)  •  \(statusLabel(event.status))"
  }

  static func statusLabel(_ status: DoseStatus) -> String {
    switch status {
    case .taken: "Taken"
    case .skipped: "Skipped"
    case .snoozed: "Snoozed"
    }
  }

  // MARK: - Rendering (nonisolated; runs on the detached task)

  //
  // Everything below this point is `nonisolated` and operates on value-type
  // snapshots only. No SwiftData access, no live `DoseEvent` references, no
  // MainActor-isolated state. The text attributes are rebuilt per render
  // rather than held as static lets so a non-Sendable `[NSAttributedString
  // .Key: Any]` doesn't have to leak isolation guarantees.

  // Fixed black / gray (not `UIColor.label` / `.secondaryLabel`). The PDF
  // context has no trait collection, so adaptive colors resolve in the
  // *device's* current style — a dark-mode iPhone would render white text on
  // a white PDF background and ship a blank document to the doctor. Pin to
  // print-correct values. `UIColor` is Sendable (iOS 17+), so the lets can
  // be `nonisolated`.
  private nonisolated static let primaryInkColor = UIColor.black
  private nonisolated static let secondaryInkColor = UIColor(white: 0.4, alpha: 1)

  /// Locale pinned to US English for the doctor export — a CI runner or
  /// device set to a non-English locale would otherwise produce "30 mai 2026"
  /// in the day headers and slip test assertions. The PDF is a US-Letter
  /// English-language document; the formatter follows. `Date.FormatStyle`
  /// is `Sendable`, so the lets can be `nonisolated`.
  private nonisolated static let dayHeaderFormatStyle = Date.FormatStyle(date: .complete, time: .omitted)
    .locale(Locale(identifier: "en_US"))
  /// Same locale pin for the footer's "Generated …" stamp so the header and
  /// footer never disagree on language inside one document.
  private nonisolated static let footerDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
    .locale(Locale(identifier: "en_US"))

  /// `render` is `nonisolated` because all its inputs are `Sendable` value
  /// snapshots and `UIGraphicsPDFRenderer` doesn't require MainActor. The
  /// share-sheet caller awaits this on a detached task so a dense history
  /// (or a slow CG context) doesn't stall the UI.
  nonisolated static func render(
    blocks: [PDFDayBlockSnapshot],
    layout: PDFLayoutConstants,
    now: Date,
    disclaimer: String,
    to url: URL
  ) throws -> URL {
    let pages = PDFPaginator.paginate(blocks, layout: layout)
    let metadata: [String: Any] = [
      kCGPDFContextCreator as String: "PillBreakfast",
      kCGPDFContextTitle as String: "PillBreakfast — last 30 days",
    ]
    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = metadata
    let renderer = UIGraphicsPDFRenderer(
      bounds: CGRect(x: 0, y: 0, width: layout.pageWidth, height: layout.pageHeight),
      format: format
    )
    let totalPages = max(pages.count, 1)
    try renderer.writePDF(to: url) { ctx in
      if pages.isEmpty {
        ctx.beginPage()
        drawEmptyState(layout: layout, pageIndex: 0, totalPages: totalPages, generatedAt: now, disclaimer: disclaimer)
      } else {
        for (pageIndex, page) in pages.enumerated() {
          ctx.beginPage()
          drawBody(blocks: page, layout: layout)
          drawFooter(
            layout: layout,
            pageIndex: pageIndex,
            totalPages: totalPages,
            generatedAt: now,
            disclaimer: disclaimer
          )
        }
      }
    }
    // `.public` is safe here — the export filename has no PHI and the page
    // count is structural metadata, not patient data.
    logger.info("Exported 30-day PDF: \(totalPages, privacy: .public) page(s)")
    return url
  }

  private nonisolated static func titleAttributes() -> [NSAttributedString.Key: Any] {
    [
      .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
      .foregroundColor: primaryInkColor,
    ]
  }

  private nonisolated static func bodyAttributes() -> [NSAttributedString.Key: Any] {
    [
      .font: UIFont.systemFont(ofSize: 11, weight: .regular),
      .foregroundColor: primaryInkColor,
    ]
  }

  private nonisolated static func secondaryAttributes() -> [NSAttributedString.Key: Any] {
    [
      .font: UIFont.systemFont(ofSize: 10, weight: .regular),
      .foregroundColor: secondaryInkColor,
    ]
  }

  private nonisolated static func footerAttributes() -> [NSAttributedString.Key: Any] {
    [
      .font: UIFont.systemFont(ofSize: 9, weight: .regular),
      .foregroundColor: secondaryInkColor,
    ]
  }

  private nonisolated static func rightAlignedParagraphStyle() -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .right
    return style
  }

  /// Precondition: `blocks` were partitioned by `PDFPaginator.paginate` so
  /// the cumulative height stays within `layout.bodyHeight`. Drawing
  /// un-paginated blocks here would overflow into the footer band. Enforced
  /// with `preconditionFailure` (not `assert`) because for a medical
  /// export, silently obscuring the footer is a worse outcome than failing.
  private nonisolated static func drawBody(blocks: [PDFDayBlockSnapshot], layout: PDFLayoutConstants) {
    let totalHeight = blocks.reduce(CGFloat(0)) { $0 + $1.height(layout: layout) }
    // `+ 1` tolerance absorbs the floating-point accumulation across the
    // per-block height sums; without it a paginator-correct page can fail
    // this guard by a fractional pt.
    if totalHeight > layout.bodyHeight + 1 {
      preconditionFailure(
        "drawBody received un-paginated blocks (\(totalHeight) > \(layout.bodyHeight)) — call PDFPaginator.paginate first"
      )
    }
    var y = layout.contentTop
    let title = titleAttributes()
    let body = bodyAttributes()
    let secondary = secondaryAttributes()
    for block in blocks {
      let header = block.date.formatted(dayHeaderFormatStyle)
      header.draw(at: CGPoint(x: layout.contentLeft, y: y), withAttributes: title)
      y += layout.dayHeaderHeight
      // Intentional split: every event is rendered (a skipped lithium dose
      // is medically relevant for the doctor's read), but only `.taken`
      // events contribute to the ingredient roll-up in `aggregateIngredients`
      // — those are the ones that reached the body.
      for row in block.rows {
        row.displayLine.draw(at: CGPoint(x: layout.contentLeft + layout.rowIndent, y: y), withAttributes: body)
        y += layout.eventRowHeight
      }
      for amount in block.ingredientTotals {
        let row = "\(amount.ingredientName): \(MgFormatter.format(amount.totalMg))"
        row.draw(at: CGPoint(x: layout.contentLeft + layout.rowIndent, y: y), withAttributes: secondary)
        y += layout.summaryRowHeight
      }
      y += layout.sectionPadding
    }
  }

  /// Footer band: seeded-ingredient disclaimer on the left, page counter on
  /// the right, generation timestamp on the second line. The disclaimer is
  /// the one carried by `IngredientLibrarySeeder` so it can never drift from
  /// the in-app text the user already saw on the Ingredients screen.
  private nonisolated static func drawFooter(
    layout: PDFLayoutConstants,
    pageIndex: Int,
    totalPages: Int,
    generatedAt: Date,
    disclaimer: String
  ) {
    let footerY = layout.pageHeight - layout.margin - layout.footerHeight
    let leftWidth = (layout.contentRight - layout.contentLeft) * 0.7
    let rightWidth = (layout.contentRight - layout.contentLeft) - leftWidth
    let leftRect = CGRect(
      x: layout.contentLeft,
      y: footerY,
      width: leftWidth,
      height: layout.footerHeight
    )
    let rightRect = CGRect(
      x: layout.contentLeft + leftWidth,
      y: footerY,
      width: rightWidth,
      height: layout.footerHeight
    )
    disclaimer.draw(in: leftRect, withAttributes: footerAttributes())
    let pageCounter = "Page \(pageIndex + 1) of \(totalPages)"
    let pageRect = CGRect(
      x: rightRect.minX,
      y: footerY,
      width: rightWidth,
      height: layout.footerLineHeight
    )
    let pageAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 9, weight: .regular),
      .foregroundColor: secondaryInkColor,
      .paragraphStyle: rightAlignedParagraphStyle(),
    ]
    pageCounter.draw(in: pageRect, withAttributes: pageAttributes)
    let stamp = "Generated \(generatedAt.formatted(footerDateStyle))"
    let stampRect = CGRect(
      x: rightRect.minX,
      y: footerY + layout.footerLineSpacing,
      width: rightWidth,
      height: layout.footerLineHeight
    )
    stamp.draw(in: stampRect, withAttributes: pageAttributes)
  }

  /// "No doses logged" surface for an empty 30-day window. Still renders the
  /// disclaimer so a doctor unsure why the export is blank sees the
  /// PillBreakfast caveat.
  private nonisolated static func drawEmptyState(
    layout: PDFLayoutConstants,
    pageIndex: Int,
    totalPages: Int,
    generatedAt: Date,
    disclaimer: String
  ) {
    let header = "No doses logged in the last 30 days."
    header.draw(at: CGPoint(x: layout.contentLeft, y: layout.contentTop), withAttributes: titleAttributes())
    drawFooter(
      layout: layout,
      pageIndex: pageIndex,
      totalPages: totalPages,
      generatedAt: generatedAt,
      disclaimer: disclaimer
    )
  }
}

enum PDFExporterError: Error {
  /// `Calendar` failed to produce the 30-day window boundary.
  case calendarArithmeticFailed
}
