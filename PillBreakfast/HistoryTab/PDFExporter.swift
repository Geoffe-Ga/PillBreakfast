import Foundation
import os
import PDFKit
import SwiftData
import UIKit

/// Produces the 30-day medication-history PDF Geoff hands his psychiatrist
/// (SPEC §2.4 / §6.2). All work is offline — `UIGraphicsPDFRenderer` is
/// `UIKit` / `CoreGraphics`-only and never touches the network. The output
/// file lives in the user's temporary directory; the share sheet (issue #57)
/// picks up the URL.
///
/// TODO(#57): `UIGraphicsPDFRenderer.writePDF` blocks the calling actor. The
/// SwiftData fetch needs MainActor, but the render pass does not — when the
/// share-sheet host lands, split `collectBlocks` (MainActor) from a
/// `Task.detached` render so a long export doesn't stall the UI. Note that
/// `PDFDayBlock.events` currently holds live `DoseEvent` instances; the
/// detach will need a value-type projection (e.g. a `PDFDayBlockSnapshot`
/// with name/qty/time materialized) so the renderer doesn't reach into the
/// model context off-actor.
@MainActor
enum PDFExporter {
  /// Window matches the History tab: 30 days inclusive (today + 29 prior).
  static let windowDays = 30

  private static let logger = Logger(
    subsystem: "com.creekmasons.pillbreakfast",
    category: "PDFExport"
  )

  /// Render the export and return the temp-directory URL. Throws on
  /// SwiftData fetch failure, calendar-arithmetic failure, or
  /// `UIGraphicsPDFRenderer.writePDF` failure. The caller (the share-sheet
  /// host) gets the URL on success or surfaces the thrown error.
  static func exportLast30Days(
    from context: ModelContext,
    now: Date = .now,
    calendar: Calendar = .current,
    layout: PDFLayoutConstants = .letter
  ) throws -> URL {
    let blocks = try collectBlocks(in: context, now: now, calendar: calendar)
    let pages = PDFPaginator.paginate(blocks, layout: layout)
    let url = temporaryURL()
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
        drawEmptyState(layout: layout, pageIndex: 0, totalPages: totalPages, generatedAt: now)
      } else {
        for (pageIndex, page) in pages.enumerated() {
          ctx.beginPage()
          drawBody(blocks: page, layout: layout, calendar: calendar)
          drawFooter(
            layout: layout,
            pageIndex: pageIndex,
            totalPages: totalPages,
            generatedAt: now
          )
        }
      }
    }
    return url
  }

  // MARK: - Data collection

  /// Fetch every `DoseEvent` in the 30-day window, group them by calendar
  /// day, and roll up `.taken` event `ingredientAmounts` into per-day
  /// totals. Reads the denormalized snapshot, never the live product graph
  /// (SPEC §5.3 / CLAUDE.md).
  ///
  /// Visibility note: this stays `internal` (not `private`) so it can be
  /// exercised from `@testable` tests and split out for the async boundary
  /// in #57 — `collectBlocks` is the MainActor-bound piece, the renderer
  /// can run detached.
  static func collectBlocks(
    in context: ModelContext,
    now: Date,
    calendar: Calendar
  ) throws -> [PDFDayBlock] {
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
      return PDFDayBlock(date: day, events: dayEvents, ingredientTotals: totals)
    }
  }

  /// Per-day ingredient roll-up: sum mg by `ingredientID`, keep the earliest
  /// snapshot's name, and sort alphabetically for stable display. Only
  /// `.taken` events contribute, matching `HistoryQueries.dailySummary`.
  ///
  /// - Precondition: `events` is sorted ascending by `takenAt`. The
  ///   "earliest-name wins" rule reads the first occurrence in the iteration
  ///   order, so an unsorted slice would silently pick the wrong name. The
  ///   sole production caller is `collectBlocks`, which uses
  ///   `SortDescriptor(\DoseEvent.takenAt)` in its fetch.
  /// - Note: the in-method `assert` is elided in release. Production callers
  ///   are responsible for honoring the precondition.
  static func aggregateIngredients(in events: [DoseEvent]) -> [LoggedIngredientAmount] {
    assert(
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
      .appendingPathComponent("PillBreakfast-\(UUID().uuidString).pdf")
  }

  // MARK: - Rendering

  // Fixed black / gray (not `UIColor.label` / `.secondaryLabel`). The PDF
  // context has no trait collection, so adaptive colors resolve in the
  // *device's* current style — a dark-mode iPhone would render white text on
  // a white PDF background and ship a blank document to the doctor. Pin to
  // print-correct values.
  private static let primaryInkColor = UIColor.black
  private static let secondaryInkColor = UIColor(white: 0.4, alpha: 1)

  private static let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
    .foregroundColor: primaryInkColor,
  ]

  private static let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: primaryInkColor,
  ]

  private static let secondaryAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
    .foregroundColor: secondaryInkColor,
  ]

  private static let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
    .foregroundColor: secondaryInkColor,
  ]

  /// Locale pinned to US English for the doctor export — a CI runner or
  /// device set to a non-English locale would otherwise produce "30 mai 2026"
  /// in the day headers and slip test assertions. The PDF is a US-Letter
  /// English-language document; the formatter follows.
  private static let dayHeaderFormatStyle = Date.FormatStyle(date: .complete, time: .omitted)
    .locale(Locale(identifier: "en_US"))

  /// Precondition: `blocks` were partitioned by `PDFPaginator.paginate` so
  /// the cumulative height stays within `layout.bodyHeight`. Drawing
  /// un-paginated blocks here would overflow into the footer band. Enforced
  /// with `preconditionFailure` (not `assert`) because for a medical
  /// export, silently obscuring the footer is a worse outcome than failing.
  private static func drawBody(blocks: [PDFDayBlock], layout: PDFLayoutConstants, calendar: Calendar) {
    let totalHeight = blocks.reduce(CGFloat(0)) { $0 + $1.height(layout: layout) }
    if totalHeight > layout.bodyHeight + 1 {
      preconditionFailure(
        "drawBody received un-paginated blocks (\(totalHeight) > \(layout.bodyHeight)) — call PDFPaginator.paginate first"
      )
    }
    var y = layout.contentTop
    for block in blocks {
      let header = block.date.formatted(dayHeaderFormatStyle)
      header.draw(at: CGPoint(x: layout.contentLeft, y: y), withAttributes: titleAttributes)
      y += layout.dayHeaderHeight
      for event in block.events {
        let row = eventRow(event)
        row.draw(at: CGPoint(x: layout.contentLeft + layout.rowIndent, y: y), withAttributes: bodyAttributes)
        y += layout.eventRowHeight
      }
      for amount in block.ingredientTotals {
        let row = "\(amount.ingredientName): \(MgFormatter.format(amount.totalMg))"
        row.draw(at: CGPoint(x: layout.contentLeft + layout.rowIndent, y: y), withAttributes: secondaryAttributes)
        y += layout.summaryRowHeight
      }
      y += layout.sectionPadding
    }
  }

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

  /// Footer band: seeded-ingredient disclaimer on the left, page counter on
  /// the right, generation timestamp on the second line. The disclaimer is
  /// the one carried by `IngredientLibrarySeeder` so it can never drift from
  /// the in-app text the user already saw on the Ingredients screen.
  private static func drawFooter(
    layout: PDFLayoutConstants,
    pageIndex: Int,
    totalPages: Int,
    generatedAt: Date
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
    IngredientLibrarySeeder.disclaimer.draw(in: leftRect, withAttributes: footerAttributes)
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
      .paragraphStyle: rightAlignedParagraphStyle,
    ]
    pageCounter.draw(in: pageRect, withAttributes: pageAttributes)
    let stamp = "Generated \(generatedAt.formatted(date: .abbreviated, time: .shortened))"
    let stampRect = CGRect(
      x: rightRect.minX,
      y: footerY + layout.footerLineSpacing,
      width: rightWidth,
      height: layout.footerLineHeight
    )
    stamp.draw(in: stampRect, withAttributes: pageAttributes)
  }

  private static let rightAlignedParagraphStyle: NSParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.alignment = .right
    return style
  }()

  /// "No doses logged" surface for an empty 30-day window. Still renders the
  /// disclaimer so a doctor unsure why the export is blank sees the
  /// PillBreakfast caveat.
  private static func drawEmptyState(
    layout: PDFLayoutConstants,
    pageIndex: Int,
    totalPages: Int,
    generatedAt: Date
  ) {
    let header = "No doses logged in the last 30 days."
    header.draw(at: CGPoint(x: layout.contentLeft, y: layout.contentTop), withAttributes: titleAttributes)
    drawFooter(
      layout: layout,
      pageIndex: pageIndex,
      totalPages: totalPages,
      generatedAt: generatedAt
    )
  }
}

enum PDFExporterError: Error {
  /// `Calendar` failed to produce the 30-day window boundary.
  case calendarArithmeticFailed
}
