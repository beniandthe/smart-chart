#if canImport(UIKit) && canImport(PencilKit)
import CoreGraphics
import PencilKit
import UIKit
import XCTest
@testable import SmartChart

final class RhythmicNotationQuantizerTests: XCTestCase {
    func testQuantizerExpandsConnectedBeamedEighthPairs() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 280, height: 88)
        let drawing = PKDrawing(strokes: [
            beamedEighthPair(startX: 22),
            beamedEighthPair(startX: 92),
            dottedQuarter(x: 164),
            singleEighth(x: 220)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .dottedQuarter, .eighth])
    }

    func testQuantizerReadsDirectBeamStrokeAcrossSeparateEighthStems() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            directBeamedEighthPair(startX: 22),
            directBeamedEighthPair(startX: 92),
            halfNote(x: 172)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerReadsLooseFloatingBeamAcrossSeparateEighthStems() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            looselyBeamedEighthPair(startX: 22),
            looselyBeamedEighthPair(startX: 92),
            halfNote(x: 172)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerKeepsAdjacentDirectBeamGroupsAsEighths() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 220, height: 88)
        let drawing = PKDrawing(strokes: [
            directBeamedEighthPair(startX: 22),
            directBeamedEighthPair(startX: 68),
            halfNote(x: 146)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerKeepsAdjacentLooseFloatingBeamGroupsAsEighths() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 220, height: 88)
        let drawing = PKDrawing(strokes: [
            looselyBeamedEighthPair(startX: 22),
            looselyBeamedEighthPair(startX: 68),
            halfNote(x: 146)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerReadsLooseBeamsRegardlessOfStrokeOrder() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            looselyBeamedEighthPairDrawnOutOfOrder(startX: 22),
            looselyBeamedEighthPairDrawnOutOfOrder(startX: 92),
            halfNote(x: 172)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerKeepsAdjacentStemAndBeamShorthandGroupsAsEighths() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 220, height: 88)
        let drawing = PKDrawing(strokes: [
            stemAndBeamOnlyPair(startX: 22),
            stemAndBeamOnlyPair(startX: 68),
            halfNote(x: 146)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerReadsStemAndBeamShorthandAsEighths() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 220, height: 88)
        let drawing = PKDrawing(strokes: [
            stemAndBeamOnlyPair(startX: 22),
            stemAndBeamOnlyPair(startX: 92),
            halfNote(x: 164)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .eighth, .eighth, .half])
    }

    func testQuantizerReadsSingleStrokeQuarterRest() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            singleStrokeQuarterRest(x: 24),
            quarterNote(x: 86),
            quarterNote(x: 142),
            quarterNote(x: 198)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.quarterRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsLooseTwoStrokeQuarterRests() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 240, height: 88)
        let drawing = PKDrawing(strokes: [
            looseTwoStrokeQuarterRest(x: 24),
            looseTwoStrokeQuarterRest(x: 82),
            halfNote(x: 156)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.quarterRest, .quarterRest, .half])
    }

    func testQuantizerKeepsEighthRestsDistinctFromQuarterRests() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            eighthRest(x: 24),
            eighthRest(x: 72),
            quarterNote(x: 126),
            quarterNote(x: 174),
            quarterNote(x: 222)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsMessyZigZagQuarterRests() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 240, height: 88)
        let drawing = PKDrawing(strokes: [
            denseZigZagQuarterRest(x: 24),
            wideZigZagQuarterRest(x: 82),
            halfNote(x: 156)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.quarterRest, .quarterRest, .half])
    }

    func testQuantizerReadsSmallLeftHookEighthRests() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            leftHookEighthRest(x: 24),
            leftHookEighthRest(x: 74),
            quarterNote(x: 130),
            quarterNote(x: 180),
            quarterNote(x: 230)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsOneStrokeHookedEighthRests() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            singleStrokeHookedEighthRest(x: 24),
            singleStrokeHookedEighthRest(x: 74),
            quarterNote(x: 130),
            quarterNote(x: 180),
            quarterNote(x: 230)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsEighthRestsDrawnTailFirst() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            tailFirstEighthRest(x: 24),
            tailFirstEighthRest(x: 74),
            quarterNote(x: 130),
            quarterNote(x: 180),
            quarterNote(x: 230)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsEighthRestHooksDrawnInEitherDirection() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            rightwardHookEighthRest(x: 24),
            leftHookEighthRest(x: 74),
            quarterNote(x: 130),
            quarterNote(x: 180),
            quarterNote(x: 230)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerReadsStandardEighthRestGesture() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            standardEighthRest(x: 24),
            standardEighthRest(x: 74),
            quarterNote(x: 130),
            quarterNote(x: 180),
            quarterNote(x: 230)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighthRest, .quarter, .quarter, .quarter])
    }

    func testQuantizerKeepsEighthRestBeforeNearbyEighthNote() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            compactEighthRest(x: 24),
            singleEighth(x: 56),
            quarterNote(x: 122),
            halfNote(x: 190)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .quarter, .half])
    }

    func testQuantizerReadsTouchedUpQuarterRestSquiggles() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 240, height: 88)
        let drawing = PKDrawing(strokes: [
            touchedUpQuarterRest(x: 24),
            wideZigZagQuarterRest(x: 82),
            halfNote(x: 156)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.quarterRest, .quarterRest, .half])
    }

    private func beamedEighthPair(startX: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: startX + 4, y: 60),
                CGPoint(x: startX + 4, y: 22),
                CGPoint(x: startX + 38, y: 22),
                CGPoint(x: startX + 38, y: 60)
            ]),
            filledNotehead(center: CGPoint(x: startX + 4, y: 60)),
            filledNotehead(center: CGPoint(x: startX + 38, y: 60))
        ]
    }

    private func directBeamedEighthPair(startX: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: startX + 4, y: 60)),
            stroke([
                CGPoint(x: startX + 8, y: 58),
                CGPoint(x: startX + 8, y: 22)
            ]),
            filledNotehead(center: CGPoint(x: startX + 38, y: 60)),
            stroke([
                CGPoint(x: startX + 42, y: 58),
                CGPoint(x: startX + 42, y: 22)
            ]),
            stroke([
                CGPoint(x: startX + 8, y: 22),
                CGPoint(x: startX + 42, y: 22)
            ])
        ]
    }

    private func looselyBeamedEighthPair(startX: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: startX + 4, y: 60)),
            stroke([
                CGPoint(x: startX + 8, y: 58),
                CGPoint(x: startX + 8, y: 22)
            ]),
            filledNotehead(center: CGPoint(x: startX + 38, y: 60)),
            stroke([
                CGPoint(x: startX + 42, y: 58),
                CGPoint(x: startX + 42, y: 22)
            ]),
            stroke([
                CGPoint(x: startX + 15, y: 20),
                CGPoint(x: startX + 35, y: 21)
            ])
        ]
    }

    private func looselyBeamedEighthPairDrawnOutOfOrder(startX: CGFloat) -> [PKStroke] {
        let leftHead = filledNotehead(center: CGPoint(x: startX + 4, y: 60))
        let leftStem = stroke([
            CGPoint(x: startX + 8, y: 58),
            CGPoint(x: startX + 8, y: 22)
        ])
        let rightHead = filledNotehead(center: CGPoint(x: startX + 38, y: 60))
        let rightStem = stroke([
            CGPoint(x: startX + 42, y: 58),
            CGPoint(x: startX + 42, y: 22)
        ])
        let beam = stroke([
            CGPoint(x: startX + 15, y: 20),
            CGPoint(x: startX + 35, y: 21)
        ])

        return [beam, rightStem, rightHead, leftStem, leftHead]
    }

    private func stemAndBeamOnlyPair(startX: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: startX + 8, y: 60),
                CGPoint(x: startX + 8, y: 22)
            ]),
            stroke([
                CGPoint(x: startX + 42, y: 60),
                CGPoint(x: startX + 42, y: 22)
            ]),
            stroke([
                CGPoint(x: startX + 8, y: 22),
                CGPoint(x: startX + 42, y: 22)
            ])
        ]
    }

    private func dottedQuarter(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x, y: 60)),
            stroke([
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 5, y: 22)
            ]),
            filledNotehead(center: CGPoint(x: x + 18, y: 61), radius: 2.2)
        ]
    }

    private func singleEighth(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x, y: 60)),
            stroke([
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 5, y: 22)
            ]),
            stroke([
                CGPoint(x: x + 5, y: 22),
                CGPoint(x: x + 18, y: 31),
                CGPoint(x: x + 13, y: 38)
            ])
        ]
    }

    private func halfNote(x: CGFloat) -> [PKStroke] {
        [
            hollowNotehead(center: CGPoint(x: x, y: 60)),
            stroke([
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 5, y: 22)
            ])
        ]
    }

    private func quarterNote(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x, y: 60)),
            stroke([
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 5, y: 22)
            ])
        ]
    }

    private func singleStrokeQuarterRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 8, y: 22),
                CGPoint(x: x + 2, y: 34),
                CGPoint(x: x + 11, y: 45),
                CGPoint(x: x + 4, y: 56),
                CGPoint(x: x + 10, y: 68)
            ])
        ]
    }

    private func looseTwoStrokeQuarterRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 8, y: 23),
                CGPoint(x: x + 2, y: 36),
                CGPoint(x: x + 10, y: 46)
            ]),
            stroke([
                CGPoint(x: x + 9, y: 45),
                CGPoint(x: x + 3, y: 56),
                CGPoint(x: x + 10, y: 67)
            ])
        ]
    }

    private func eighthRest(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x + 4, y: 28), radius: 2.8),
            stroke([
                CGPoint(x: x + 8, y: 28),
                CGPoint(x: x + 4, y: 40),
                CGPoint(x: x + 12, y: 61)
            ])
        ]
    }

    private func standardEighthRest(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x + 4, y: 28), radius: 2.8),
            stroke([
                CGPoint(x: x + 7, y: 30),
                CGPoint(x: x + 14, y: 38)
            ]),
            stroke([
                CGPoint(x: x + 13, y: 38),
                CGPoint(x: x + 8, y: 64)
            ])
        ]
    }

    private func denseZigZagQuarterRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 9, y: 20),
                CGPoint(x: x + 2, y: 31),
                CGPoint(x: x + 12, y: 38),
                CGPoint(x: x + 3, y: 48),
                CGPoint(x: x + 11, y: 55),
                CGPoint(x: x + 5, y: 68)
            ])
        ]
    }

    private func wideZigZagQuarterRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 13, y: 22),
                CGPoint(x: x + 1, y: 34),
                CGPoint(x: x + 17, y: 46),
                CGPoint(x: x + 6, y: 58),
                CGPoint(x: x + 14, y: 69)
            ])
        ]
    }

    private func leftHookEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 9, y: 25),
                CGPoint(x: x + 2, y: 25),
                CGPoint(x: x + 5, y: 31)
            ]),
            stroke([
                CGPoint(x: x + 8, y: 27),
                CGPoint(x: x + 5, y: 42),
                CGPoint(x: x + 12, y: 63)
            ])
        ]
    }

    private func singleStrokeHookedEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 11, y: 24),
                CGPoint(x: x + 3, y: 25),
                CGPoint(x: x + 6, y: 31),
                CGPoint(x: x + 8, y: 44),
                CGPoint(x: x + 14, y: 65)
            ])
        ]
    }

    private func tailFirstEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 13, y: 65),
                CGPoint(x: x + 8, y: 44),
                CGPoint(x: x + 6, y: 31),
                CGPoint(x: x + 3, y: 25),
                CGPoint(x: x + 11, y: 24)
            ])
        ]
    }

    private func rightwardHookEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 2, y: 25),
                CGPoint(x: x + 10, y: 25),
                CGPoint(x: x + 7, y: 33)
            ]),
            stroke([
                CGPoint(x: x + 8, y: 28),
                CGPoint(x: x + 5, y: 43),
                CGPoint(x: x + 12, y: 64)
            ])
        ]
    }

    private func compactEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 2, y: 38),
                CGPoint(x: x + 12, y: 38),
                CGPoint(x: x + 9, y: 44)
            ]),
            stroke([
                CGPoint(x: x + 11, y: 40),
                CGPoint(x: x + 8, y: 54),
                CGPoint(x: x + 13, y: 68)
            ])
        ]
    }

    private func touchedUpQuarterRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 11, y: 21),
                CGPoint(x: x + 3, y: 33)
            ]),
            stroke([
                CGPoint(x: x + 3, y: 33),
                CGPoint(x: x + 18, y: 44)
            ]),
            stroke([
                CGPoint(x: x + 18, y: 44),
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 13, y: 69)
            ]),
            stroke([
                CGPoint(x: x + 7, y: 37),
                CGPoint(x: x + 14, y: 44),
                CGPoint(x: x + 8, y: 53)
            ])
        ]
    }

    private func filledNotehead(center: CGPoint, radius: CGFloat = 4.4) -> PKStroke {
        var points: [CGPoint] = []
        for index in 0...12 {
            let angle = CGFloat(index) / 12 * .pi * 2
            points.append(
                CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius * 0.78
                )
            )
        }
        points.append(center)
        points.append(CGPoint(x: center.x - radius * 0.65, y: center.y))
        points.append(CGPoint(x: center.x + radius * 0.65, y: center.y))
        return stroke(points)
    }

    private func hollowNotehead(center: CGPoint, radius: CGFloat = 5.0) -> PKStroke {
        var points: [CGPoint] = []
        for index in 0...14 {
            let angle = CGFloat(index) / 14 * .pi * 2
            points.append(
                CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius * 0.72
                )
            )
        }
        return stroke(points)
    }

    private func stroke(_ points: [CGPoint]) -> PKStroke {
        let controlPoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: 3, height: 3),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: .black), path: path)
    }
}
#endif
