#if canImport(UIKit)
import PencilKit
import XCTest
@testable import SmartChart

final class LeadSheetChordInkRecognitionSchedulingTests: XCTestCase {
    func testIdleDelayCurrentlyUsesConfiguredDefault() {
        XCTAssertEqual(
            LeadSheetChordInkRecognitionScheduling.idleDelay(
                for: PKDrawing(),
                defaultDelay: 1.2
            ),
            1.2
        )
    }

    func testClearRootCanPayIdleDelayAndContinuationGraceBeforeProposal() throws {
        let idleDelay = 1.2
        let continuationGraceDelay = 1.2
        let result = try recognitionResult(for: "C", confidence: 4.5)
        let drawingData = Data([0x43])
        let timing = recognitionTiming(requestedDelay: idleDelay, strokeCount: 1)

        XCTAssertTrue(
            LeadSheetChordInkRecognitionScheduling.shouldGiveContinuationGrace(
                previousDrawingData: nil,
                drawingData: drawingData,
                timing: timing,
                idleDelay: idleDelay,
                result: result
            )
        )
        XCTAssertEqual(idleDelay + continuationGraceDelay, 2.4, accuracy: 0.001)
    }

    func testContinuationGraceDoesNotRepeatForSameDrawingData() throws {
        let result = try recognitionResult(for: "C", confidence: 4.5)
        let drawingData = Data([0x43])

        XCTAssertFalse(
            LeadSheetChordInkRecognitionScheduling.shouldGiveContinuationGrace(
                previousDrawingData: drawingData,
                drawingData: drawingData,
                timing: recognitionTiming(requestedDelay: 1.2, strokeCount: 1),
                idleDelay: 1.2,
                result: result
            )
        )
    }

    func testSlashAndAlteredChordsDoNotUseContinuationGrace() throws {
        let timing = recognitionTiming(requestedDelay: 1.2, strokeCount: 6)
        let drawingData = Data([0x01])

        for chord in ["G/B", "Db7(b9)"] {
            XCTAssertFalse(
                LeadSheetChordInkRecognitionScheduling.shouldGiveContinuationGrace(
                    previousDrawingData: nil,
                    drawingData: drawingData,
                    timing: timing,
                    idleDelay: 1.2,
                    result: try recognitionResult(for: chord, confidence: 4.5)
                ),
                chord
            )
        }
    }

    private func recognitionResult(
        for text: String,
        confidence: Double
    ) throws -> ChordInkRecognitionResult {
        let match = try XCTUnwrap(ChordRecognitionCompendium.match(text), text)
        return ChordInkRecognitionResult(
            rawCandidates: [text],
            glyphCandidates: [],
            match: match,
            confidence: confidence,
            candidateScores: [
                ChordInkCandidateScore(
                    text: text,
                    displayText: match.displayText,
                    confidence: confidence
                )
            ]
        )
    }

    private func recognitionTiming(
        requestedDelay: TimeInterval,
        strokeCount: Int
    ) -> ChordInkRecognitionTiming {
        let scheduledAt = Date(timeIntervalSince1970: 0)
        let recognitionStartedAt = scheduledAt.addingTimeInterval(requestedDelay)
        return ChordInkRecognitionTiming(
            scheduledAt: scheduledAt,
            requestedDelay: requestedDelay,
            recognitionStartedAt: recognitionStartedAt,
            recognitionFinishedAt: recognitionStartedAt.addingTimeInterval(0.02),
            strokeCount: strokeCount,
            ocrCandidateCount: 0
        )
    }
}
#endif
