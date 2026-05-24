#if canImport(UIKit)
import Foundation
import UIKit

enum LeadSheetActiveInkScope {
    case page(frame: CGRect)
    case chords(frame: CGRect)
    case rhythmicMeasure(measureID: UUID, frame: CGRect)
    case noteSelection(frame: CGRect)

    var frame: CGRect {
        switch self {
        case .page(let frame), .chords(let frame), .rhythmicMeasure(_, let frame), .noteSelection(let frame):
            return frame
        }
    }

    static func resolve(
        interactionMode: EditorCanvasMode,
        selectedMeasureID: UUID?,
        selectedMeasureLayout: LeadSheetMeasureLayout?,
        pageLayout: LeadSheetPageLayout?
    ) -> LeadSheetActiveInkScope? {
        if interactionMode.allowsDirectRhythmicNotationInk,
           let selectedMeasureID,
           let selectedMeasureLayout {
            return .rhythmicMeasure(
                measureID: selectedMeasureID,
                frame: selectedMeasureLayout.writableFrame.insetBy(dx: 2, dy: 2)
            )
        }

        if interactionMode.allowsNoteSelectionInk,
           let pageLayout {
            return .noteSelection(frame: pageWritingFrame(for: pageLayout))
        }

        if interactionMode.allowsChordInkEditing,
           let pageLayout {
            return .chords(frame: chordWritingFrame(for: pageLayout))
        }

        guard interactionMode.allowsPageInkEditing,
              let pageLayout else {
            return nil
        }

        return .page(frame: pageWritingFrame(for: pageLayout))
    }

    static func pageWritingFrame(for pageLayout: LeadSheetPageLayout) -> CGRect {
        pageLayout.paperFrame.insetBy(dx: 10, dy: 10)
    }

    static func chordWritingFrame(for pageLayout: LeadSheetPageLayout) -> CGRect {
        pageLayout.paperFrame.insetBy(dx: 10, dy: 10)
    }

    func drawingData(in chart: Chart) -> Data? {
        switch self {
        case .page:
            return chart.pageHandwrittenNotationData
        case .chords:
            return chart.pageHandwrittenChordData
        case .rhythmicMeasure(let measureID, _):
            return chart.measure(id: measureID)?.handwrittenRhythmicNotationData
        case .noteSelection:
            return nil
        }
    }

    func chartByPersistingDrawingData(_ drawingData: Data?, in chart: Chart) -> Chart? {
        var updatedChart = chart

        switch self {
        case .page:
            guard chart.pageHandwrittenNotationData != drawingData,
                  updatedChart.setPageHandwrittenNotationDrawing(drawingData) else {
                return nil
            }
        case .chords:
            guard chart.pageHandwrittenChordData != drawingData,
                  updatedChart.setPageHandwrittenChordDrawing(drawingData) else {
                return nil
            }
        case .rhythmicMeasure(let measureID, _):
            guard chart.measure(id: measureID)?.handwrittenRhythmicNotationData != drawingData,
                  updatedChart.setMeasureHandwrittenRhythmicNotationDrawing(drawingData, for: measureID) else {
                return nil
            }
        case .noteSelection:
            return nil
        }

        return updatedChart
    }
}
#endif
