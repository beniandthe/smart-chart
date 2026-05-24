#if canImport(UIKit)
import Foundation
import UIKit

struct ActiveMeasureResizeDrag {
    enum Edge {
        case left
        case right
    }

    var measureID: UUID
    var edge: Edge
    var initialWidth: CGFloat
}

struct LeadSheetMeasureResizeHandleFrames {
    let left: CGRect
    let right: CGRect
}

enum LeadSheetMeasureResizeGeometry {
    static func handleFrames(for measure: LeadSheetMeasureLayout) -> LeadSheetMeasureResizeHandleFrames {
        let handleSize = CGSize(width: 18, height: 34)
        let handleY = measure.staffFrame.midY - handleSize.height / 2
        return LeadSheetMeasureResizeHandleFrames(
            left: CGRect(
                x: measure.frame.minX - handleSize.width / 2,
                y: handleY,
                width: handleSize.width,
                height: handleSize.height
            ),
            right: CGRect(
                x: measure.frame.maxX - handleSize.width / 2,
                y: handleY,
                width: handleSize.width,
                height: handleSize.height
            )
        )
    }

    static func hitTarget(at location: CGPoint, in measure: LeadSheetMeasureLayout) -> ActiveMeasureResizeDrag? {
        guard let measureID = measure.sourceMeasureID else {
            return nil
        }

        let handleFrames = handleFrames(for: measure)
        let touchInsetX: CGFloat = -12
        let touchInsetY: CGFloat = -10

        if handleFrames.left.insetBy(dx: touchInsetX, dy: touchInsetY).contains(location) {
            return ActiveMeasureResizeDrag(
                measureID: measureID,
                edge: .left,
                initialWidth: measure.frame.width
            )
        }

        if handleFrames.right.insetBy(dx: touchInsetX, dy: touchInsetY).contains(location) {
            return ActiveMeasureResizeDrag(
                measureID: measureID,
                edge: .right,
                initialWidth: measure.frame.width
            )
        }

        return nil
    }
}
#endif
