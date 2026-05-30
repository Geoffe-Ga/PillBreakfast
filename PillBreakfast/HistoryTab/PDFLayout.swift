import CoreGraphics
import Foundation

/// US-Letter portrait sizing for the doctor-export PDF. Constants are pulled
/// out so the pagination algorithm can be exercised against arbitrary block
/// sizes in tests without rendering.
///
/// `nonisolated` so the detached `PDFExporter.render` (and its helpers) can
/// read layout constants without hopping back to the MainActor — the values
/// are immutable `Sendable` primitives.
nonisolated struct PDFLayoutConstants {
  let pageWidth: CGFloat
  let pageHeight: CGFloat
  let margin: CGFloat
  let footerHeight: CGFloat
  let dayHeaderHeight: CGFloat
  let eventRowHeight: CGFloat
  let summaryRowHeight: CGFloat
  let sectionPadding: CGFloat
  /// Indent applied to event and ingredient-total rows so the day header
  /// reads as the section title.
  let rowIndent: CGFloat
  /// Vertical spacing between the two right-aligned footer lines (page
  /// counter and generation timestamp). Tied to the footer font's line
  /// height; centralized here so tweaks move together.
  let footerLineSpacing: CGFloat
  /// Height of a single right-aligned footer text row. Sized for the 9pt
  /// footer font with a hair of breathing room.
  let footerLineHeight: CGFloat

  /// Default US-Letter portrait sizing — 612×792 pt at 72 dpi.
  static let letter = PDFLayoutConstants(
    pageWidth: 612,
    pageHeight: 792,
    margin: 36,
    footerHeight: 48,
    dayHeaderHeight: 24,
    eventRowHeight: 16,
    summaryRowHeight: 14,
    sectionPadding: 8,
    rowIndent: 12,
    footerLineSpacing: 14,
    footerLineHeight: 12
  )

  var contentTop: CGFloat {
    margin
  }

  var contentLeft: CGFloat {
    margin
  }

  var contentRight: CGFloat {
    pageWidth - margin
  }

  /// Vertical budget for day blocks per page. Reserves the footer band so the
  /// disclaimer + page number have a clean strip below the last block.
  var bodyHeight: CGFloat {
    pageHeight - margin * 2 - footerHeight
  }
}

/// Pre-formatted event row inside a day block. `displayLine` is materialized
/// at collection time (MainActor) by `PDFExporter.eventRow(_:)` so the renderer
/// can run off-MainActor without reaching into the SwiftData object graph.
nonisolated struct PDFEventRowSnapshot {
  let displayLine: String
}

/// One calendar day in the 30-day export window — `Sendable` projection of
/// the underlying `DoseEvent`s so the snapshot can cross the actor boundary
/// from the MainActor collect phase to the detached render. Stores
/// pre-formatted rows plus the day's ingredient totals; pagination only has
/// to ask each block for its height once.
nonisolated struct PDFDayBlockSnapshot: Identifiable {
  let date: Date
  let rows: [PDFEventRowSnapshot]
  let ingredientTotals: [LoggedIngredientAmount]

  var id: Date {
    date
  }

  func height(layout: PDFLayoutConstants) -> CGFloat {
    layout.dayHeaderHeight
      + CGFloat(rows.count) * layout.eventRowHeight
      + CGFloat(ingredientTotals.count) * layout.summaryRowHeight
      + layout.sectionPadding
  }
}

nonisolated enum PDFPaginator {
  /// Partition `blocks` into pages. A block never splits across a page — at
  /// 12 doses/day the worst-case block height stays well under one page, so
  /// the simpler atomic-block algorithm is enough. An oversized block (would
  /// only happen with a fixture much taller than US Letter) still gets its
  /// own page rather than being silently dropped.
  static func paginate(_ blocks: [PDFDayBlockSnapshot], layout: PDFLayoutConstants) -> [[PDFDayBlockSnapshot]] {
    var pages: [[PDFDayBlockSnapshot]] = []
    var current: [PDFDayBlockSnapshot] = []
    var consumed: CGFloat = 0
    let budget = layout.bodyHeight

    for block in blocks {
      let blockHeight = block.height(layout: layout)
      let wouldOverflow = consumed + blockHeight > budget
      if wouldOverflow, !current.isEmpty {
        pages.append(current)
        current = []
        consumed = 0
      }
      current.append(block)
      consumed += blockHeight
    }
    if !current.isEmpty {
      pages.append(current)
    }
    return pages
  }
}
