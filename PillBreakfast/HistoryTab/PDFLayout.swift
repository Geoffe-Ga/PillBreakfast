import CoreGraphics
import Foundation

/// US-Letter portrait sizing for the doctor-export PDF. Constants are pulled
/// out so the pagination algorithm can be exercised against arbitrary block
/// sizes in tests without rendering.
struct PDFLayoutConstants: Hashable {
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
    footerLineSpacing: 14
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

/// One calendar day in the 30-day export window. Carries the events to render
/// plus the pre-computed ingredient totals so pagination only has to ask each
/// block for its height once.
struct PDFDayBlock: Identifiable {
  let date: Date
  let events: [DoseEvent]
  let ingredientTotals: [LoggedIngredientAmount]

  var id: Date {
    date
  }

  func height(layout: PDFLayoutConstants) -> CGFloat {
    layout.dayHeaderHeight
      + CGFloat(events.count) * layout.eventRowHeight
      + CGFloat(ingredientTotals.count) * layout.summaryRowHeight
      + layout.sectionPadding
  }
}

enum PDFPaginator {
  /// Partition `blocks` into pages. A block never splits across a page — at
  /// 12 doses/day the worst-case block height stays well under one page, so
  /// the simpler atomic-block algorithm is enough. An oversized block (would
  /// only happen with a fixture much taller than US Letter) still gets its
  /// own page rather than being silently dropped.
  static func paginate(_ blocks: [PDFDayBlock], layout: PDFLayoutConstants) -> [[PDFDayBlock]] {
    var pages: [[PDFDayBlock]] = []
    var current: [PDFDayBlock] = []
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
