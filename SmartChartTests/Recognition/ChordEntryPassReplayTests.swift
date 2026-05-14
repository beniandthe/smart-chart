#if canImport(PencilKit)
import Foundation
import XCTest
@testable import SmartChart

final class ChordEntryPassReplayTests: XCTestCase {
    func testReplayChordWritingTestChartFromSavedState() throws {
        guard let statePath = ProcessInfo.processInfo.environment["SMART_CHART_STATE"] else {
            throw XCTSkip("Set SMART_CHART_STATE to a simulator library-state.json to replay saved chord ink.")
        }

        let repository = FileChartRepository(url: URL(fileURLWithPath: statePath))
        let snapshot = try XCTUnwrap(try repository.loadSnapshot())
        let chart = try XCTUnwrap(
            snapshot.charts.first { $0.title == "Chord Writing Test Chart" },
            "Expected a Chord Writing Test Chart in \(statePath)."
        )
        let recognizer = ChordInkRecognizer()

        for measure in chart.measures {
            for chordEvent in measure.chordEvents {
                guard let sourceInkData = chordEvent.sourceInkData else {
                    XCTFail("Missing source ink for \(chordEvent.symbol.displayText) in measure \(measure.index).")
                    continue
                }

                let strokes = try PencilKitInkAdapter.inkStrokes(from: sourceInkData)
                let result = recognizer.recognize(strokes: strokes)
                let decision = ChordInkRecognitionPolicy.decision(for: result)
                let savedText = chordEvent.rawInput ?? chordEvent.symbol.displayText
                let matchText = result.match?.displayText ?? "nil"
                let scores = result.candidateScores
                    .prefix(6)
                    .map { score in
                        let display = score.displayText ?? score.text
                        return "\(display):\(String(format: "%.3f", score.confidence))"
                    }
                    .joined(separator: ",")

                print(
                    [
                        "measure=\(measure.index)",
                        "saved=\(savedText)",
                        "match=\(matchText)",
                        "confidence=\(String(format: "%.3f", result.confidence))",
                        "action=\(decision.action)",
                        "gap=\(decision.confidenceGap.map { String(format: "%.3f", $0) } ?? "nil")",
                        "scores=[\(scores)]"
                    ].joined(separator: " ")
                )
            }
        }
    }
}
#endif
