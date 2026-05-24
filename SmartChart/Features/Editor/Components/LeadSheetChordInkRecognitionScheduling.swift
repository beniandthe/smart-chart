import Foundation
import PencilKit

enum LeadSheetChordInkRecognitionScheduling {
    static func idleDelay(
        for _: PKDrawing,
        defaultDelay: TimeInterval
    ) -> TimeInterval {
        defaultDelay
    }

    static func shouldGiveContinuationGrace(
        previousDrawingData: Data?,
        drawingData: Data,
        timing: ChordInkRecognitionTiming,
        idleDelay: TimeInterval,
        result: ChordInkRecognitionResult
    ) -> Bool {
        guard previousDrawingData != drawingData,
              timing.requestedDelay <= idleDelay + 0.01,
              ChordInkContinuationGracePolicy.shouldWaitForPossibleContinuation(
                  result: result,
                  strokeCount: timing.strokeCount
              ) else {
            return false
        }

        return true
    }
}
