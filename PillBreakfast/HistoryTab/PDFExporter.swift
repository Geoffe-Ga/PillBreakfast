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
    let url = temporaryURL(now: now)
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
        drawEmptyState(layout: layout, pageIndex: 0, totalPages: 1, generatedAt: now)
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
  /// snapshot's name (`events` is fetched ascending so the first event seen
  /// is the earliest of the day), and sort alphabetically for stable display.
  /// Only `.taken` events contribute, matching `HistoryQueries.dailySummary`.
  static func aggregateIngredients(in events: [DoseEvent]) -> [LoggedIngredientAmount] {
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

  static func temporaryURL(now: Date) -> URL {
    // Suffix the timestamp so repeated exports in the same session don't
    // collide (and Mail's preview cache distinguishes them).
    let stamp = Int(now.timeIntervalSince1970)
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("PillBreakfast-\(stamp).pdf")
  }

  // MARK: - Rendering

  private static let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
    .foregroundColor: UIColor.label,
  ]

  private static let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: UIColor.label,
  ]

  private static let secondaryAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
    .foregroundColor: UIColor.secondaryLabel,
  ]

  private static let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
    .foregroundColor: UIColor.secondaryLabel,
  ]

  private static func drawBody(blocks: [PDFDayBlock], layout: PDFLayoutConstants, calendar: Calendar) {
    var y = layout.contentTop
    for block in blocks {
      let header = block.date.formatted(date: .complete, time: .omitted)
      header.draw(at: CGPoint(x: layout.contentLeft, y: y), withAttributes: titleAttributes)
      y += layout.dayHeaderHeight
      for event in block.events {
        let row = eventRow(event)
        row.draw(at: CGPoint(x: layout.contentLeft + 12, y: y), withAttributes: bodyAttributes)
        y += layout.eventRowHeight
      }
      for amount in block.ingredientTotals {
        let row = "\(amount.ingredientName): \(formatMg(amount.totalMg))"
        row.draw(at: CGPoint(x: layout.contentLeft + 12, y: y), withAttributes: secondaryAttributes)
        y += layout.summaryRowHeight
      }
      y += layout.sectionPadding
    }
  }

  static func eventRow(_ event: DoseEvent) -> String {
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

  static func formatMg(_ mg: Double) -> String {
    guard mg.isFinite else { return "— mg" }
    return "\(Int(mg.rounded())) mg"
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
      height: 12
    )
    let pageAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.systemFont(ofSize: 9, weight: .regular),
      .foregroundColor: UIColor.secondaryLabel,
      .paragraphStyle: rightAlignedParagraphStyle(),
    ]
    pageCounter.draw(in: pageRect, withAttributes: pageAttributes)
    let stamp = "Generated \(generatedAt.formatted(date: .abbreviated, time: .shortened))"
    let stampRect = CGRect(
      x: rightRect.minX,
      y: footerY + 14,
      width: rightWidth,
      height: 12
    )
    stamp.draw(in: stampRect, withAttributes: pageAttributes)
  }

  private static func rightAlignedParagraphStyle() -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .right
    return style
  }

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
