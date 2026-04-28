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

    func testQuantizerReadsSimpleSlashesAsQuarterBeatPlaceholders() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 280, height: 88)
        let drawing = PKDrawing(strokes: [
            rhythmSlash(x: 24),
            rhythmSlash(x: 84),
            rhythmSlash(x: 144),
            rhythmSlash(x: 204)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.slash, .slash, .slash, .slash])
    }

    func testQuantizerDoesNotTreatBackslashesAsSlashPlaceholders() {
        let drawingFrame = CGRect(x: 0, y: 0, width: 280, height: 88)
        let drawing = PKDrawing(strokes: [
            rhythmSlash(x: 24, direction: .backslash),
            rhythmSlash(x: 84, direction: .backslash),
            rhythmSlash(x: 144, direction: .backslash),
            rhythmSlash(x: 204, direction: .backslash)
        ].flatMap { $0 })

        do {
            let values = try RhythmicNotationQuantizer.quantize(
                drawing: drawing,
                meter: Meter(numerator: 4, denominator: 4),
                drawingFrame: drawingFrame
            )

            XCTAssertFalse(values.contains(.slash))
        } catch {
            return
        }
    }

    func testQuantizerReadsLooseForwardDiagonalSlashesAsPlaceholders() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 280, height: 88)
        let drawing = PKDrawing(strokes: [
            looseRhythmSlash(x: 24, shape: .shallow),
            looseRhythmSlash(x: 84, shape: .steep),
            looseRhythmSlash(x: 144, shape: .wobbly),
            looseRhythmSlash(x: 204, shape: .veryWobbly)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.slash, .slash, .slash, .slash])
    }

    func testQuantizerReadsTightlySpacedForwardSlashesAsSeparatePlaceholders() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 180, height: 88)
        let drawing = PKDrawing(strokes: [
            rhythmSlash(x: 24),
            rhythmSlash(x: 50),
            rhythmSlash(x: 76),
            rhythmSlash(x: 102)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.slash, .slash, .slash, .slash])
    }

    func testQuantizerMixesSlashesWithWrittenRhythms() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 280, height: 88)
        let drawing = PKDrawing(strokes: [
            rhythmSlash(x: 24),
            directBeamedEighthPair(startX: 88),
            halfNote(x: 202)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.slash, .eighth, .eighth, .half])
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

    func testQuantizerReadsDotTailEighthRestsWithWobblyTails() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 270, height: 88)
        let drawing = PKDrawing(strokes: [
            dotTailEighthRest(x: 24, tail: .vertical),
            dotTailEighthRest(x: 74, tail: .wobbly),
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

    func testQuantizerReadsDotTailRestDottedQuarterHalfFromSparseLiveInk() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 244, height: 78)
        let drawing = PKDrawing(strokes: [
            sparseDotTailEighthRest(x: 24),
            sparseDottedQuarterWithTapDot(x: 50),
            sparseHalfNote(x: 109)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .dottedQuarter, .half])
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

    func testQuantizerReadsLeftHookSevenMarksAsEighthRests() throws {
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

    func testQuantizerReadsOneStrokeSevenMarksAsEighthRests() throws {
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

    func testQuantizerReadsTailFirstSevenMarksAsEighthRests() throws {
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

    func testQuantizerReadsTwoStrokeSevenMarksAsEighthRests() throws {
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

    func testQuantizerReadsThreePartVisualEighthRestSymbol() throws {
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

    func testQuantizerReadsVisualSymbolsRegardlessOfStrokeOrder() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 244, height: 78)
        let drawing = PKDrawing(strokes: [
            sparseDottedQuarterWithTapDot(x: 50).reversed(),
            sparseHalfNote(x: 109).reversed(),
            sparseDotTailEighthRest(x: 24).reversed()
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .dottedQuarter, .half])
    }

    func testQuantizerSplitsLoopedDotHookTailEighthRestSymbolFromDottedQuarterAndHalf() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 244, height: 78)
        let drawing = PKDrawing(strokes: [
            loopedDotHookTailEighthRestSymbol(x: 13),
            sparseDottedQuarterWithTapDot(x: 48),
            sparseHalfNote(x: 114)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .dottedQuarter, .half])
    }

    func testQuantizerReadsOneTakeDotHookTailAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            oneTakeDotHookTailEighthRest(x: 18),
            singleEighth(x: 58),
            dottedHalfNote(x: 124)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsSevenLikeMarkAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            sevenLikeEighthRest(x: 20),
            singleEighth(x: 64),
            dottedHalfNote(x: 126)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsWideSevenLikeMarkAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            wideSevenLikeEighthRest(x: 18),
            singleEighth(x: 62),
            dottedHalfNote(x: 124)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsWobblySevenLikeMarkAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            wobblySevenLikeEighthRest(x: 18),
            singleEighth(x: 62),
            dottedHalfNote(x: 124)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsLiveWobblySevenLikeMarkAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            liveWobblySevenLikeEighthRest(),
            singleEighth(x: 64),
            dottedHalfNote(x: 126)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsCurrentOneStrokeSevenLikeMarkAsEighthRestSymbol() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            currentOneStrokeSevenLikeEighthRest(),
            singleEighth(x: 72),
            dottedHalfNote(x: 132)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }

    func testQuantizerReadsCurrentScreenEighthRestEighthDottedHalf() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: currentScreenEighthRestEighthDottedHalf())

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .dottedHalf])
    }


    func testQuantizerDoesNotStealOneTakeEighthRestAsEighthNote() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 300, height: 88)
        let drawing = PKDrawing(strokes: [
            oneTakeDotHookTailEighthRest(x: 24),
            singleEighth(x: 72),
            quarterNote(x: 132),
            halfNote(x: 210)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighthRest, .eighth, .quarter, .half])
    }

    func testQuantizerDoesNotReadLowerEighthNoteHeadAsTopDotEighthRest() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 300, height: 88)
        let drawing = PKDrawing(strokes: [
            singleEighth(x: 24),
            singleEighth(x: 72),
            quarterNote(x: 132),
            halfNote(x: 210)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.eighth, .eighth, .quarter, .half])
    }

    func testQuantizerCollapsesTouchedUpNoteheadInkIntoOneVisualQuarter() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            touchedUpQuarterNote(x: 24),
            touchedUpQuarterNote(x: 84),
            touchedUpQuarterNote(x: 144),
            touchedUpQuarterNote(x: 204)
        ].flatMap { $0 })

        let values = try RhythmicNotationQuantizer.quantize(
            drawing: drawing,
            meter: Meter(numerator: 4, denominator: 4),
            drawingFrame: drawingFrame
        )

        XCTAssertEqual(values, [.quarter, .quarter, .quarter, .quarter])
    }

    func testQuantizerKeepsEighthRestBeforeNearbyEighthNote() throws {
        let drawingFrame = CGRect(x: 0, y: 0, width: 260, height: 88)
        let drawing = PKDrawing(strokes: [
            eighthRest(x: 24),
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

    private func dottedHalfNote(x: CGFloat) -> [PKStroke] {
        halfNote(x: x) + [
            filledNotehead(center: CGPoint(x: x + 24, y: 61), radius: 2.2)
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

    private func touchedUpQuarterNote(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x, y: 60)),
            filledNotehead(center: CGPoint(x: x + 1.5, y: 60.5), radius: 3.0),
            stroke([
                CGPoint(x: x + 5, y: 58),
                CGPoint(x: x + 5, y: 22)
            ])
        ]
    }

    private enum SlashDirection {
        case slash
        case backslash
    }

    private enum LooseSlashShape {
        case shallow
        case steep
        case wobbly
        case veryWobbly
        case short
    }

    private enum EighthRestTailShape {
        case vertical
        case wobbly
    }

    private func rhythmSlash(x: CGFloat, direction: SlashDirection = .slash) -> [PKStroke] {
        switch direction {
        case .slash:
            return [
                stroke([
                    CGPoint(x: x + 4, y: 64),
                    CGPoint(x: x + 14, y: 47),
                    CGPoint(x: x + 28, y: 28)
                ])
            ]
        case .backslash:
            return [
                stroke([
                    CGPoint(x: x + 4, y: 28),
                    CGPoint(x: x + 15, y: 47),
                    CGPoint(x: x + 28, y: 64)
                ])
            ]
        }
    }

    private func looseRhythmSlash(x: CGFloat, shape: LooseSlashShape) -> [PKStroke] {
        let points: [CGPoint]
        switch shape {
        case .shallow:
            points = [
                CGPoint(x: x + 3, y: 58),
                CGPoint(x: x + 15, y: 51),
                CGPoint(x: x + 31, y: 44)
            ]
        case .steep:
            points = [
                CGPoint(x: x + 12, y: 64),
                CGPoint(x: x + 17, y: 50),
                CGPoint(x: x + 22, y: 36)
            ]
        case .wobbly:
            points = [
                CGPoint(x: x + 4, y: 66),
                CGPoint(x: x + 11, y: 55),
                CGPoint(x: x + 9, y: 49),
                CGPoint(x: x + 18, y: 40),
                CGPoint(x: x + 24, y: 29)
            ]
        case .veryWobbly:
            points = [
                CGPoint(x: x + 3, y: 68),
                CGPoint(x: x + 12, y: 54),
                CGPoint(x: x + 7, y: 60),
                CGPoint(x: x + 18, y: 40),
                CGPoint(x: x + 15, y: 46),
                CGPoint(x: x + 28, y: 22)
            ]
        case .short:
            points = [
                CGPoint(x: x + 8, y: 57),
                CGPoint(x: x + 15, y: 48),
                CGPoint(x: x + 23, y: 39)
            ]
        }

        return [stroke(points)]
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

    private func dotTailEighthRest(x: CGFloat, tail: EighthRestTailShape) -> [PKStroke] {
        let tailPoints: [CGPoint]
        switch tail {
        case .vertical:
            tailPoints = [
                CGPoint(x: x + 8, y: 29),
                CGPoint(x: x + 8, y: 44),
                CGPoint(x: x + 9, y: 64)
            ]
        case .wobbly:
            tailPoints = [
                CGPoint(x: x + 8, y: 28),
                CGPoint(x: x + 4, y: 40),
                CGPoint(x: x + 11, y: 50),
                CGPoint(x: x + 9, y: 66)
            ]
        }

        return [
            filledNotehead(center: CGPoint(x: x + 4, y: 28), radius: 2.8),
            stroke(tailPoints)
        ]
    }

    private func sparseDotTailEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 1, y: 38),
                CGPoint(x: x + 4, y: 36),
                CGPoint(x: x + 7, y: 40),
                CGPoint(x: x + 3, y: 42)
            ]),
            stroke([
                CGPoint(x: x + 7, y: 38),
                CGPoint(x: x + 4, y: 47),
                CGPoint(x: x + 11, y: 55),
                CGPoint(x: x + 9, y: 62)
            ])
        ]
    }

    private func sparseDottedQuarterWithTapDot(x: CGFloat) -> [PKStroke] {
        [
            filledNotehead(center: CGPoint(x: x + 3, y: 54), radius: 3.2),
            stroke([
                CGPoint(x: x + 5, y: 50),
                CGPoint(x: x + 5, y: 26)
            ]),
            stroke([
                CGPoint(x: x + 13, y: 55)
            ])
        ]
    }

    private func sparseHalfNote(x: CGFloat) -> [PKStroke] {
        [
            hollowNotehead(center: CGPoint(x: x + 9, y: 53), radius: 8.2),
            stroke([
                CGPoint(x: x + 17, y: 44),
                CGPoint(x: x + 17, y: 17)
            ])
        ]
    }

    private func loopedDotHookTailEighthRestSymbol(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 4.5, y: 40.6),
                CGPoint(x: x + 6.7, y: 40.9),
                CGPoint(x: x + 8.5, y: 42.0),
                CGPoint(x: x + 8.5, y: 44.0),
                CGPoint(x: x + 8.0, y: 46.3),
                CGPoint(x: x + 7.0, y: 48.5),
                CGPoint(x: x + 4.5, y: 48.8),
                CGPoint(x: x + 1.5, y: 48.8),
                CGPoint(x: x + 1.5, y: 46.5),
                CGPoint(x: x + 2.5, y: 45.0),
                CGPoint(x: x + 4.0, y: 44.2),
                CGPoint(x: x + 5.9, y: 43.8),
                CGPoint(x: x + 8.5, y: 44.0),
                CGPoint(x: x + 6.9, y: 46.9),
                CGPoint(x: x + 5.5, y: 48.1),
                CGPoint(x: x + 4.0, y: 49.0),
                CGPoint(x: x + 1.5, y: 48.3),
                CGPoint(x: x + 2.7, y: 46.8),
                CGPoint(x: x + 4.0, y: 45.0),
                CGPoint(x: x + 5.5, y: 43.7),
                CGPoint(x: x + 8.1, y: 42.8),
                CGPoint(x: x + 7.0, y: 44.0),
                CGPoint(x: x + 4.5, y: 45.5),
                CGPoint(x: x + 3.6, y: 46.7),
                CGPoint(x: x + 1.0, y: 47.0),
                CGPoint(x: x + 4.0, y: 47.0),
                CGPoint(x: x + 6.0, y: 47.0),
                CGPoint(x: x + 8.2, y: 46.8),
                CGPoint(x: x + 10.0, y: 46.5),
                CGPoint(x: x + 12.7, y: 46.5),
                CGPoint(x: x + 15.9, y: 46.2),
                CGPoint(x: x + 20.0, y: 45.5),
                CGPoint(x: x + 23.5, y: 44.8),
                CGPoint(x: x + 25.5, y: 43.5),
                CGPoint(x: x + 24.0, y: 48.0),
                CGPoint(x: x + 20.0, y: 53.5),
                CGPoint(x: x + 18.2, y: 56.9),
                CGPoint(x: x + 15.5, y: 61.5),
                CGPoint(x: x + 10.0, y: 70.0)
            ])
        ]
    }

    private func oneTakeDotHookTailEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 2.0, y: 41.0),
                CGPoint(x: x + 3.1, y: 42.2),
                CGPoint(x: x + 3.5, y: 45.0),
                CGPoint(x: x + 1.3, y: 44.6),
                CGPoint(x: x + 2.0, y: 41.0),
                CGPoint(x: x + 3.4, y: 42.4),
                CGPoint(x: x + 3.5, y: 44.0),
                CGPoint(x: x + 3.5, y: 45.5),
                CGPoint(x: x + 1.4, y: 46.2),
                CGPoint(x: x + 1.0, y: 44.0),
                CGPoint(x: x + 4.0, y: 44.0),
                CGPoint(x: x + 6.5, y: 45.0),
                CGPoint(x: x + 3.5, y: 45.5),
                CGPoint(x: x + 1.0, y: 45.5),
                CGPoint(x: x + 2.3, y: 43.1),
                CGPoint(x: x + 3.9, y: 41.3),
                CGPoint(x: x + 7.7, y: 40.9),
                CGPoint(x: x + 7.6, y: 42.8),
                CGPoint(x: x + 6.5, y: 45.5),
                CGPoint(x: x + 5.0, y: 48.0),
                CGPoint(x: x + 3.5, y: 49.5),
                CGPoint(x: x + 2.0, y: 50.0),
                CGPoint(x: x + 1.3, y: 47.2),
                CGPoint(x: x + 1.0, y: 44.0),
                CGPoint(x: x + 1.4, y: 40.3),
                CGPoint(x: x + 3.5, y: 40.0),
                CGPoint(x: x + 5.1, y: 43.5),
                CGPoint(x: x + 6.5, y: 45.5),
                CGPoint(x: x + 5.0, y: 47.2),
                CGPoint(x: x + 2.1, y: 48.0),
                CGPoint(x: x + 1.0, y: 47.0),
                CGPoint(x: x + 1.0, y: 45.3),
                CGPoint(x: x + 1.3, y: 43.8),
                CGPoint(x: x + 3.5, y: 42.5),
                CGPoint(x: x + 3.5, y: 45.3),
                CGPoint(x: x + 2.5, y: 46.5),
                CGPoint(x: x + 6.5, y: 45.5),
                CGPoint(x: x + 8.4, y: 44.7),
                CGPoint(x: x + 10.7, y: 43.9),
                CGPoint(x: x + 12.5, y: 43.5),
                CGPoint(x: x + 12.7, y: 45.5),
                CGPoint(x: x + 14.0, y: 50.0),
                CGPoint(x: x + 12.5, y: 56.5),
                CGPoint(x: x + 9.5, y: 63.0),
                CGPoint(x: x + 8.5, y: 65.2),
                CGPoint(x: x + 6.5, y: 67.5)
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

    private func sevenLikeEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 4, y: 28),
                CGPoint(x: x + 15, y: 28),
                CGPoint(x: x + 12, y: 35),
                CGPoint(x: x + 9, y: 46),
                CGPoint(x: x + 6, y: 63)
            ])
        ]
    }

    private func wideSevenLikeEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 3, y: 32),
                CGPoint(x: x + 29, y: 30),
                CGPoint(x: x + 22, y: 37),
                CGPoint(x: x + 14, y: 49),
                CGPoint(x: x + 8, y: 64)
            ])
        ]
    }

    private func wobblySevenLikeEighthRest(x: CGFloat) -> [PKStroke] {
        [
            stroke([
                CGPoint(x: x + 4, y: 29),
                CGPoint(x: x + 17, y: 28),
                CGPoint(x: x + 27, y: 31),
                CGPoint(x: x + 22, y: 36),
                CGPoint(x: x + 16, y: 42),
                CGPoint(x: x + 18, y: 47),
                CGPoint(x: x + 12, y: 55),
                CGPoint(x: x + 9, y: 66)
            ])
        ]
    }

    private func liveWobblySevenLikeEighthRest() -> [PKStroke] {
        [
            stroke([
                CGPoint(x: 11.0, y: 38.5),
                CGPoint(x: 13.3, y: 38.5),
                CGPoint(x: 13.7, y: 40.0),
                CGPoint(x: 12.5, y: 41.0),
                CGPoint(x: 14.8, y: 40.7),
                CGPoint(x: 12.5, y: 41.5),
                CGPoint(x: 11.0, y: 41.5),
                CGPoint(x: 9.1, y: 41.3),
                CGPoint(x: 9.2, y: 39.3),
                CGPoint(x: 11.7, y: 38.6),
                CGPoint(x: 13.2, y: 38.5),
                CGPoint(x: 15.2, y: 38.5),
                CGPoint(x: 13.5, y: 38.5),
                CGPoint(x: 14.9, y: 40.0),
                CGPoint(x: 12.0, y: 41.0),
                CGPoint(x: 10.5, y: 40.0),
                CGPoint(x: 12.5, y: 40.2),
                CGPoint(x: 14.0, y: 41.0),
                CGPoint(x: 17.2, y: 41.0),
                CGPoint(x: 18.7, y: 40.8),
                CGPoint(x: 20.5, y: 40.5),
                CGPoint(x: 22.3, y: 40.0),
                CGPoint(x: 23.9, y: 39.5),
                CGPoint(x: 27.3, y: 38.5),
                CGPoint(x: 28.5, y: 37.5),
                CGPoint(x: 28.8, y: 39.3),
                CGPoint(x: 29.6, y: 41.6),
                CGPoint(x: 30.5, y: 44.0),
                CGPoint(x: 31.0, y: 45.8),
                CGPoint(x: 31.8, y: 48.4),
                CGPoint(x: 32.0, y: 50.0),
                CGPoint(x: 32.0, y: 52.5),
                CGPoint(x: 32.0, y: 54.1),
                CGPoint(x: 32.0, y: 56.0),
                CGPoint(x: 31.6, y: 57.6),
                CGPoint(x: 31.5, y: 60.5),
                CGPoint(x: 31.0, y: 62.5),
                CGPoint(x: 31.0, y: 64.5)
            ])
        ]
    }

    private func currentOneStrokeSevenLikeEighthRest() -> [PKStroke] {
        [
            stroke([
                CGPoint(x: 22.5, y: 50.0),
                CGPoint(x: 19.0, y: 50.0),
                CGPoint(x: 19.0, y: 47.7),
                CGPoint(x: 19.5, y: 46.1),
                CGPoint(x: 21.0, y: 45.4),
                CGPoint(x: 23.6, y: 44.9),
                CGPoint(x: 23.6, y: 46.7),
                CGPoint(x: 22.6, y: 45.5),
                CGPoint(x: 24.0, y: 43.5),
                CGPoint(x: 24.0, y: 46.0),
                CGPoint(x: 22.8, y: 47.3),
                CGPoint(x: 24.0, y: 45.0),
                CGPoint(x: 24.0, y: 47.0),
                CGPoint(x: 26.3, y: 45.1),
                CGPoint(x: 29.3, y: 43.9),
                CGPoint(x: 32.5, y: 43.0),
                CGPoint(x: 35.1, y: 41.4),
                CGPoint(x: 37.5, y: 40.5),
                CGPoint(x: 41.6, y: 39.8),
                CGPoint(x: 40.5, y: 43.5),
                CGPoint(x: 38.8, y: 48.2),
                CGPoint(x: 37.0, y: 52.5),
                CGPoint(x: 34.0, y: 61.0),
                CGPoint(x: 32.9, y: 64.6),
                CGPoint(x: 32.5, y: 67.5)
            ])
        ]
    }

    private func currentScreenEighthRestEighthDottedHalf() -> [PKStroke] {
        [
            stroke([
                CGPoint(x: 22.5, y: 50.0),
                CGPoint(x: 19.0, y: 50.0),
                CGPoint(x: 19.0, y: 47.7),
                CGPoint(x: 19.5, y: 46.1),
                CGPoint(x: 21.0, y: 45.4),
                CGPoint(x: 23.6, y: 44.9),
                CGPoint(x: 23.6, y: 46.7),
                CGPoint(x: 22.6, y: 45.5),
                CGPoint(x: 24.0, y: 43.5),
                CGPoint(x: 24.0, y: 46.0),
                CGPoint(x: 22.8, y: 47.3),
                CGPoint(x: 24.0, y: 45.0),
                CGPoint(x: 24.0, y: 47.0),
                CGPoint(x: 26.3, y: 45.1),
                CGPoint(x: 29.3, y: 43.9),
                CGPoint(x: 32.5, y: 43.0),
                CGPoint(x: 35.1, y: 41.4),
                CGPoint(x: 37.5, y: 40.5),
                CGPoint(x: 41.6, y: 39.8),
                CGPoint(x: 40.5, y: 43.5),
                CGPoint(x: 38.8, y: 48.2),
                CGPoint(x: 37.0, y: 52.5),
                CGPoint(x: 34.0, y: 61.0),
                CGPoint(x: 32.9, y: 64.6),
                CGPoint(x: 32.5, y: 67.5)
            ]),
            stroke([
                CGPoint(x: 70.0, y: 57.5),
                CGPoint(x: 72.5, y: 57.3),
                CGPoint(x: 75.0, y: 56.5),
                CGPoint(x: 75.0, y: 58.3),
                CGPoint(x: 74.5, y: 60.2),
                CGPoint(x: 73.0, y: 62.5),
                CGPoint(x: 70.5, y: 63.8),
                CGPoint(x: 68.5, y: 65.0),
                CGPoint(x: 68.5, y: 63.5),
                CGPoint(x: 68.5, y: 61.2),
                CGPoint(x: 68.5, y: 59.0),
                CGPoint(x: 70.4, y: 57.9),
                CGPoint(x: 73.0, y: 57.5),
                CGPoint(x: 74.5, y: 58.6),
                CGPoint(x: 74.9, y: 61.7),
                CGPoint(x: 75.0, y: 63.5),
                CGPoint(x: 72.7, y: 63.8),
                CGPoint(x: 70.0, y: 64.0),
                CGPoint(x: 70.0, y: 61.8),
                CGPoint(x: 70.4, y: 58.7),
                CGPoint(x: 73.0, y: 58.5),
                CGPoint(x: 74.8, y: 59.8),
                CGPoint(x: 76.5, y: 61.0),
                CGPoint(x: 76.1, y: 63.2),
                CGPoint(x: 74.7, y: 64.6),
                CGPoint(x: 73.0, y: 65.5),
                CGPoint(x: 70.5, y: 65.3),
                CGPoint(x: 68.8, y: 64.6),
                CGPoint(x: 68.5, y: 61.5),
                CGPoint(x: 69.0, y: 60.0),
                CGPoint(x: 70.2, y: 58.7),
                CGPoint(x: 71.5, y: 58.0),
                CGPoint(x: 73.0, y: 58.5),
                CGPoint(x: 74.6, y: 59.3),
                CGPoint(x: 75.4, y: 60.9),
                CGPoint(x: 76.5, y: 62.5),
                CGPoint(x: 74.5, y: 64.0),
                CGPoint(x: 71.5, y: 65.3),
                CGPoint(x: 68.5, y: 66.5)
            ]),
            stroke([
                CGPoint(x: 76.5, y: 34.0),
                CGPoint(x: 76.5, y: 37.0),
                CGPoint(x: 76.5, y: 43.0),
                CGPoint(x: 77.6, y: 47.4),
                CGPoint(x: 78.0, y: 52.5),
                CGPoint(x: 78.0, y: 56.0),
                CGPoint(x: 78.0, y: 60.0)
            ]),
            stroke([
                CGPoint(x: 81.5, y: 34.0),
                CGPoint(x: 79.5, y: 32.0),
                CGPoint(x: 79.5, y: 30.5),
                CGPoint(x: 82.5, y: 31.6),
                CGPoint(x: 84.3, y: 33.0),
                CGPoint(x: 86.0, y: 34.5),
                CGPoint(x: 90.5, y: 37.0)
            ]),
            stroke([
                CGPoint(x: 124.0, y: 49.5),
                CGPoint(x: 124.0, y: 52.2),
                CGPoint(x: 124.0, y: 55.5),
                CGPoint(x: 124.0, y: 60.0),
                CGPoint(x: 126.8, y: 63.1),
                CGPoint(x: 128.5, y: 64.0),
                CGPoint(x: 131.6, y: 64.6),
                CGPoint(x: 133.9, y: 63.8),
                CGPoint(x: 137.0, y: 62.5),
                CGPoint(x: 137.5, y: 59.2),
                CGPoint(x: 138.5, y: 56.0),
                CGPoint(x: 138.5, y: 50.0),
                CGPoint(x: 137.0, y: 47.2),
                CGPoint(x: 135.5, y: 44.5),
                CGPoint(x: 131.8, y: 44.0),
                CGPoint(x: 127.0, y: 46.0)
            ]),
            stroke([
                CGPoint(x: 137.0, y: 25.5),
                CGPoint(x: 137.0, y: 27.0),
                CGPoint(x: 137.0, y: 29.5),
                CGPoint(x: 137.0, y: 34.5),
                CGPoint(x: 137.0, y: 40.5),
                CGPoint(x: 138.5, y: 43.2),
                CGPoint(x: 140.0, y: 47.0)
            ]),
            stroke([
                CGPoint(x: 161.5, y: 58.5),
                CGPoint(x: 160.0, y: 58.5),
                CGPoint(x: 158.0, y: 57.5)
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
