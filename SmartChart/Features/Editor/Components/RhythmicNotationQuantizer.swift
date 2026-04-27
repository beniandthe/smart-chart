#if canImport(UIKit)
import CoreGraphics
import Foundation
import PencilKit

enum RhythmicNotationQuantizationError: LocalizedError, Hashable {
    case unsupportedSymbol(Int)
    case underfilled(expectedBeats: Double, actualBeats: Double)
    case overflow(expectedBeats: Double, actualBeats: Double)

    var errorDescription: String? {
        userFacingMessage
    }

    var userFacingMessage: String {
        switch self {
        case .unsupportedSymbol(let index):
            return "Measure \(index + 1) contains a rhythm symbol that couldn’t be matched yet. The measure is still selected so you can adjust or rewrite it."
        case .underfilled(let expectedBeats, let actualBeats):
            return "This rhythm only adds up to \(formattedBeats(actualBeats)) beats, but the measure needs \(formattedBeats(expectedBeats)). The measure is still selected so you can adjust or rewrite it."
        case .overflow(let expectedBeats, let actualBeats):
            return "This rhythm adds up to \(formattedBeats(actualBeats)) beats, which is more than the \(formattedBeats(expectedBeats)) beats allowed in this measure. The measure is still selected so you can adjust or rewrite it."
        }
    }

    private func formattedBeats(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }

        return String(format: "%.1f", value)
    }
}

enum RhythmicNotationQuantizer {
    static func quantize(
        drawingData: Data,
        meter: Meter,
        drawingFrame: CGRect
    ) throws -> [RhythmValue] {
        let drawing = try PKDrawing(data: drawingData)
        return try quantize(drawing: drawing, meter: meter, drawingFrame: drawingFrame)
    }

    static func quantize(
        drawing: PKDrawing,
        meter: Meter,
        drawingFrame: CGRect
    ) throws -> [RhythmValue] {
        let strokeObservations = strokeObservations(from: drawing)
        let symbolGroups = groupedSymbols(from: strokeObservations, drawingFrame: drawingFrame)
        var candidateGroups: [[RhythmCandidate]] = []
        for (index, group) in symbolGroups.enumerated() {
            if let beamedEighthGroups = beamedEighthCandidateGroups(for: group, drawingFrame: drawingFrame) {
                candidateGroups.append(contentsOf: beamedEighthGroups)
                continue
            }

            let candidates = classifyCandidates(group, drawingFrame: drawingFrame)
            guard !candidates.isEmpty else {
                throw RhythmicNotationQuantizationError.unsupportedSymbol(index)
            }
            candidateGroups.append(candidates)
        }

        if let values = bestMeasureAlignedValues(from: candidateGroups, meter: meter) {
            return values
        }

        let expectedBeats = meter.measureLengthInWholeNotes / meter.beatUnitWholeNoteLength
        let values = bestNaturalValues(from: candidateGroups)
        let actualBeats = values.reduce(0) { partialResult, value in
            partialResult + value.wholeNoteLength / meter.beatUnitWholeNoteLength
        }
        let delta = actualBeats - expectedBeats

        if delta < 0 {
            throw RhythmicNotationQuantizationError.underfilled(
                expectedBeats: expectedBeats,
                actualBeats: actualBeats
            )
        }

        throw RhythmicNotationQuantizationError.overflow(
            expectedBeats: expectedBeats,
            actualBeats: actualBeats
        )
    }

    private static func strokeObservations(from drawing: PKDrawing) -> [StrokeObservation] {
        drawing.strokes.compactMap { stroke in
            let points = Array(stroke.path).map(\.location)
            guard points.count >= 2 else {
                return nil
            }

            let bounds = points.reduce(into: CGRect.null) { partialResult, point in
                partialResult = partialResult.union(CGRect(origin: point, size: .zero).insetBy(dx: -0.5, dy: -0.5))
            }
            let pathLength = zip(points, points.dropFirst()).reduce(CGFloat.zero) { partialResult, segment in
                partialResult + hypot(segment.1.x - segment.0.x, segment.1.y - segment.0.y)
            }
            let directionChanges = directionChangeCount(for: points)

            return StrokeObservation(
                points: points,
                bounds: bounds.integral,
                pathLength: pathLength,
                startPoint: points.first ?? .zero,
                endPoint: points.last ?? .zero,
                directionChangeCount: directionChanges
            )
        }
    }

    private static func directionChangeCount(for points: [CGPoint]) -> Int {
        guard points.count >= 3 else {
            return 0
        }

        var changeCount = 0
        for index in 0..<(points.count - 2) {
            let firstDelta = CGPoint(
                x: points[index + 1].x - points[index].x,
                y: points[index + 1].y - points[index].y
            )
            let secondDelta = CGPoint(
                x: points[index + 2].x - points[index + 1].x,
                y: points[index + 2].y - points[index + 1].y
            )
            let firstMagnitude = hypot(firstDelta.x, firstDelta.y)
            let secondMagnitude = hypot(secondDelta.x, secondDelta.y)
            guard firstMagnitude > 0.2, secondMagnitude > 0.2 else {
                continue
            }

            let dotProduct = firstDelta.x * secondDelta.x + firstDelta.y * secondDelta.y
            let cosine = dotProduct / max(0.0001, firstMagnitude * secondMagnitude)
            if cosine < 0.35 {
                changeCount += 1
            }
        }

        return changeCount
    }

    private static func groupedSymbols(
        from strokes: [StrokeObservation],
        drawingFrame: CGRect
    ) -> [SymbolObservation] {
        let sortedStrokes = strokes.sorted { lhs, rhs in
            if abs(lhs.bounds.minX - rhs.bounds.minX) > 0.5 {
                return lhs.bounds.minX < rhs.bounds.minX
            }
            return lhs.bounds.midY < rhs.bounds.midY
        }

        let gapThreshold = max(14, min(32, drawingFrame.width * 0.085))
        let dotThreshold = max(CGFloat(5), min(CGFloat(9), drawingFrame.height * 0.1))
        var groups: [[StrokeObservation]] = []

        for stroke in sortedStrokes {
            guard var currentGroup = groups.popLast() else {
                groups.append([stroke])
                continue
            }

            let currentBounds = currentGroup.reduce(into: CGRect.null) { partialResult, member in
                partialResult = partialResult.union(member.bounds)
            }
            let horizontalGap = stroke.bounds.minX - currentBounds.maxX
            let verticalDistance = abs(stroke.bounds.midY - currentBounds.midY)
            let verticalTolerance = max(18, drawingFrame.height * 0.42)
            let attachesAsDot = stroke.bounds.width <= dotThreshold
                && stroke.bounds.height <= dotThreshold
                && horizontalGap <= gapThreshold * 1.55
                && verticalDistance <= verticalTolerance
                && stroke.bounds.minX >= currentBounds.midX

            let overlapsEnough = horizontalGap <= gapThreshold
                && stroke.bounds.minY <= currentBounds.maxY + verticalTolerance * 0.65
                && stroke.bounds.maxY >= currentBounds.minY - verticalTolerance * 0.65

            if attachesAsDot || overlapsEnough {
                currentGroup.append(stroke)
                groups.append(currentGroup)
            } else {
                groups.append(currentGroup)
                groups.append([stroke])
            }
        }

        return groups
            .mergingLooseDots(drawingFrame: drawingFrame)
            .reattachingLeadingNoteheadsToFollowingBeams(drawingFrame: drawingFrame)
            .splittingCompoundStemmedSymbols(drawingFrame: drawingFrame)
            .reattachingLeadingNoteheadsToFollowingBeams(drawingFrame: drawingFrame)
            .reattachingLeadingDotsToPreviousSymbols(drawingFrame: drawingFrame)
            .map(SymbolObservation.init(strokes:))
    }

    private static func bestMeasureAlignedValues(
        from candidateGroups: [[RhythmCandidate]],
        meter: Meter
    ) -> [RhythmValue]? {
        guard !candidateGroups.isEmpty else {
            return nil
        }

        let targetUnits = rhythmUnits(forWholeNotes: meter.measureLengthInWholeNotes)
        let naturalPath = bestNaturalPath(from: candidateGroups)
        if naturalPath.units == targetUnits {
            return naturalPath.values
        }

        guard let exactPath = bestExactPath(from: candidateGroups, targetUnits: targetUnits) else {
            return nil
        }

        let tolerance = max(1.0, Double(candidateGroups.count) * 0.5)
        guard exactPath.score <= naturalPath.score + tolerance else {
            return nil
        }

        return exactPath.values
    }

    private static func bestNaturalValues(from candidateGroups: [[RhythmCandidate]]) -> [RhythmValue] {
        bestNaturalPath(from: candidateGroups).values
    }

    private static func bestNaturalPath(from candidateGroups: [[RhythmCandidate]]) -> CandidatePath {
        candidateGroups.reduce(CandidatePath(values: [], score: 0, units: 0)) { partialResult, candidates in
            guard let bestCandidate = candidates.min(by: { $0.score < $1.score }) else {
                return partialResult
            }

            return CandidatePath(
                values: partialResult.values + [bestCandidate.value],
                score: partialResult.score + bestCandidate.score,
                units: partialResult.units + rhythmUnits(for: bestCandidate.value)
            )
        }
    }

    private static func bestExactPath(
        from candidateGroups: [[RhythmCandidate]],
        targetUnits: Int
    ) -> CandidatePath? {
        var states: [Int: CandidatePath] = [
            0: CandidatePath(values: [], score: 0, units: 0)
        ]

        for candidates in candidateGroups {
            var nextStates: [Int: CandidatePath] = [:]
            for state in states.values {
                for candidate in candidates {
                    guard candidate.isConfidentEnoughForMeasureFit else {
                        continue
                    }

                    let nextUnits = state.units + rhythmUnits(for: candidate.value)
                    guard nextUnits <= targetUnits else {
                        continue
                    }

                    let nextPath = CandidatePath(
                        values: state.values + [candidate.value],
                        score: state.score + candidate.score,
                        units: nextUnits
                    )
                    if let existingPath = nextStates[nextUnits],
                       existingPath.score <= nextPath.score {
                        continue
                    }
                    nextStates[nextUnits] = nextPath
                }
            }

            states = nextStates
        }

        return states[targetUnits]
    }

    private static func rhythmUnits(for value: RhythmValue) -> Int {
        rhythmUnits(forWholeNotes: value.wholeNoteLength)
    }

    private static func rhythmUnits(forWholeNotes wholeNotes: Double) -> Int {
        Int((wholeNotes * 8).rounded())
    }

    private static func classifyCandidates(
        _ symbol: SymbolObservation,
        drawingFrame: CGRect
    ) -> [RhythmCandidate] {
        let features = SymbolFeatures(symbol: symbol, drawingFrame: drawingFrame)
        guard !features.contentStrokes.isEmpty else {
            return []
        }

        var candidateScores: [RhythmValue: Double] = [:]
        func add(_ value: RhythmValue, score: Double) {
            let clampedScore = max(0, score)
            if let existingScore = candidateScores[value],
               existingScore <= clampedScore {
                return
            }
            candidateScores[value] = clampedScore
        }

        let quarterRestMatch = looksLikeQuarterRest(features)
        let eighthRestMatch = looksLikeEighthRest(features)
        if quarterRestMatch || eighthRestMatch {
            if eighthRestMatch && (!quarterRestMatch || features.prefersEighthRestGesture) {
                add(.eighthRest, score: 0.0)
                add(.quarterRest, score: 1.35)
            } else {
                add(.quarterRest, score: 0.0)
                add(.eighthRest, score: 1.35)
            }

            return candidateScores
                .map { RhythmCandidate(value: $0.key, score: $0.value) }
                .sorted { lhs, rhs in
                    if abs(lhs.score - rhs.score) > 0.0001 {
                        return lhs.score < rhs.score
                    }
                    return lhs.value.wholeNoteLength < rhs.value.wholeNoteLength
                }
        }

        if looksLikeWholeRest(features) {
            add(.wholeRest, score: 0.05)
            add(.halfRest, score: 0.9)
        }

        if looksLikeHalfRest(features) {
            add(.halfRest, score: 0.05)
            add(.wholeRest, score: 1.15)
        }

        if features.hasStem {
            if features.hasFlag {
                add(.eighth, score: features.hasDot ? 1.25 : (features.hasLowerHeadMass ? 0.02 : 0.18))
                add(.quarter, score: features.hasDot ? 1.8 : 1.25)
            }

            if features.hasDot {
                if features.hasHollowHead && !features.hasFilledHead {
                    add(.dottedHalf, score: 0.02)
                    add(.dottedQuarter, score: 0.5)
                    add(.half, score: 1.55)
                } else if features.hasFilledHead || features.hasLowerHeadMass || features.hasStemAndKick {
                    add(.dottedQuarter, score: 0.02)
                    add(.quarter, score: 1.6)
                    add(.dottedHalf, score: 0.9)
                } else {
                    add(.dottedQuarter, score: 0.18)
                    add(.dottedHalf, score: 0.28)
                }
            }

            if features.hasHollowHead && !features.hasFilledHead {
                add(.half, score: features.hasDot ? 1.55 : 0.05)
                add(.quarter, score: 0.75)
            }

            if features.hasFilledHead || features.hasLowerHeadMass || features.hasStemAndKick {
                add(.quarter, score: features.hasDot ? 1.6 : 0.05)
                add(.half, score: 0.9)
            }
        }

        if features.hasHollowHead && !features.hasStem {
            add(.whole, score: 0.05)
            add(.half, score: 1.0)
        }

        if candidateScores.isEmpty {
            addFallbackCandidates(for: features, into: &candidateScores)
        }

        return candidateScores
            .map { RhythmCandidate(value: $0.key, score: $0.value) }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.0001 {
                    return lhs.score < rhs.score
                }
                return lhs.value.wholeNoteLength < rhs.value.wholeNoteLength
            }
    }

    private static func beamedEighthCandidateGroups(
        for symbol: SymbolObservation,
        drawingFrame: CGRect
    ) -> [[RhythmCandidate]]? {
        let noteheadCount = symbol.beamedEighthNoteCount(drawingFrame: drawingFrame)
        guard noteheadCount >= 2 else {
            return nil
        }

        return (0..<noteheadCount).map { _ in
            [RhythmCandidate(value: .eighth, score: 0.01)]
        }
    }

    private static func addFallbackCandidates(
        for features: SymbolFeatures,
        into candidateScores: inout [RhythmValue: Double]
    ) {
        func add(_ value: RhythmValue, score: Double) {
            if let existingScore = candidateScores[value],
               existingScore <= score {
                return
            }
            candidateScores[value] = score
        }

        if features.hasSingleStrokeFlagGesture {
            add(.eighth, score: 0.65)
            add(.quarter, score: 1.25)
        }

        if features.hasStem || features.height > features.width * 1.05 {
            add(.quarter, score: 1.2)
            add(.eighth, score: 1.35)
            add(.quarterRest, score: 1.45)
            add(.eighthRest, score: 1.55)
        }

        if features.width > features.height * 1.05 {
            add(.half, score: 1.25)
            add(.halfRest, score: 1.35)
            add(.whole, score: 1.55)
            add(.wholeRest, score: 1.65)
        }
    }

    private static func looksLikeQuarterRest(_ features: SymbolFeatures) -> Bool {
        guard features.contentStrokes.count <= 5,
              features.height > max(8, features.width * 0.55),
              !features.hasDefiniteLowerNotehead,
              !features.hasClearNoteGlyph else {
            return false
        }

        if features.contentStrokes.contains(where: { $0.looksLikeQuarterRestBody(in: features.contentBounds) }) {
            return true
        }

        let stackedNarrowGesture = features.contentStrokes.count >= 2
            && features.height > features.width * 0.9
            && features.contentStrokes.allSatisfy { !$0.looksClosed && !$0.looksFilledNoteHead }
            && features.contentStrokes.filter { $0.bounds.height >= features.height * 0.18 }.count >= 2
        if stackedNarrowGesture {
            return true
        }

        let angularSegments = features.contentStrokes.filter { stroke in
            stroke.looksLikeQuarterRestSegment(in: features.contentBounds)
        }
        return angularSegments.count >= 2
    }

    private static func looksLikeEighthRest(_ features: SymbolFeatures) -> Bool {
        if features.hasStandardEighthRestGesture {
            return true
        }

        guard features.contentStrokes.count <= 5,
              features.height > max(7, features.width * 0.72),
              !features.hasDefiniteLowerNotehead,
              !features.hasClearNoteGlyph else {
            return false
        }

        let upperDot = features.contentStrokes.contains {
            $0.looksLikeEighthRestHook(in: features.contentBounds)
        }
        let descendingTail = features.contentStrokes.contains { stroke in
            stroke.bounds.height > features.height * 0.32
                && stroke.center.y >= features.contentBounds.midY - features.height * 0.22
                && stroke.bounds.width < features.width * 0.95
        }

        if upperDot && descendingTail {
            return true
        }

        return features.contentStrokes.contains { stroke in
            stroke.looksLikeSingleStrokeEighthRest(in: features.contentBounds)
        }
    }

    private static func looksLikeWholeRest(_ features: SymbolFeatures) -> Bool {
        guard features.width > features.height * 1.05,
              !features.hasFlag,
              !features.hasHollowHead else {
            return false
        }

        let denseBlock = features.contentStrokes.contains { stroke in
            stroke.looksDense
                && stroke.bounds.width > stroke.bounds.height * 0.95
                && stroke.bounds.height < features.height * 0.85
        }
        let compactRestBody = features.height <= max(16, features.width * 0.7)
        return denseBlock && compactRestBody
    }

    private static func looksLikeHalfRest(_ features: SymbolFeatures) -> Bool {
        guard features.width > max(8, features.height * 1.05),
              !features.hasHollowHead,
              !features.contentStrokes.contains(where: \.looksDense) else {
            return false
        }

        let horizontalStrokes = features.contentStrokes.filter(\.isMostlyHorizontal)
        guard !horizontalStrokes.isEmpty else {
            return false
        }

        let hasUpperStroke = horizontalStrokes.contains { stroke in
            stroke.bounds.midY <= features.contentBounds.midY + features.height * 0.2
        }
        let hasBaseOrCorners = features.contentStrokes.count >= 2
            || features.contentStrokes.contains { stroke in
                stroke.bounds.width > features.width * 0.55
                    && stroke.bounds.midY >= features.contentBounds.midY - features.height * 0.2
            }

        return hasUpperStroke && hasBaseOrCorners
    }
}

private struct StrokeObservation: Hashable {
    let points: [CGPoint]
    let bounds: CGRect
    let pathLength: CGFloat
    let startPoint: CGPoint
    let endPoint: CGPoint
    let directionChangeCount: Int

    var looksClosed: Bool {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) <= max(6, pathLength * 0.12)
            && bounds.width > 5
            && bounds.height > 5
    }

    var center: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    var isMostlyVertical: Bool {
        bounds.height > max(6, bounds.width * 1.65)
    }

    var isMostlyHorizontal: Bool {
        bounds.width > max(6, bounds.height * 1.55)
    }

    var densityRatio: CGFloat {
        pathLength / max(1, (bounds.width + bounds.height) * 2)
    }

    var looksDense: Bool {
        densityRatio > 1.45 || directionChangeCount >= 5
    }

    var hasInteriorFillGesture: Bool {
        guard bounds.width > 4,
              bounds.height > 4 else {
            return false
        }

        let insetBounds = bounds.insetBy(dx: bounds.width * 0.15, dy: bounds.height * 0.15)
        let interiorPointCount = points.filter { insetBounds.contains($0) }.count
        return looksClosed && interiorPointCount >= 2
    }

    var looksHollowNoteHead: Bool {
        let ratio = bounds.width / max(1, bounds.height)
        let ovalish = ratio > 0.45 && ratio < 2.5
        let outlineLike = pathLength >= (bounds.width + bounds.height) * 0.75
            && pathLength <= (bounds.width + bounds.height) * 2.8

        return bounds.width > 5
            && bounds.height > 5
            && ovalish
            && outlineLike
            && !looksDense
            && !hasInteriorFillGesture
    }

    var looksFilledNoteHead: Bool {
        let ratio = bounds.width / max(1, bounds.height)
        let ovalish = ratio > 0.45 && ratio < 2.5
        return bounds.width > 4
            && bounds.height > 4
            && ovalish
            && (looksDense || hasInteriorFillGesture)
    }

    var looksLikeSingleStrokeEighthNote: Bool {
        let upperFlagBand = points.filter { point in
            point.y <= bounds.minY + bounds.height * 0.42
        }
        let upperXSpread = upperFlagBand.xSpread
        let hasUpperHook = upperXSpread >= max(4, bounds.width * 0.28)
        let hasEnoughBody = bounds.height > max(10, bounds.width * 1.0)
            && bounds.width >= max(5, bounds.height * 0.14)
        let hasHandwrittenTurn = directionChangeCount >= 1
            || pathLength > bounds.height * 1.22

        return hasEnoughBody
            && hasUpperHook
            && hasHandwrittenTurn
            && !looksClosed
    }

    var hasHorizontalUpperHook: Bool {
        guard points.count >= 2,
              bounds.width >= 3 else {
            return false
        }

        let topBandMaxY = bounds.minY + bounds.height * 0.38
        return zip(points, points.dropFirst()).contains { segment in
            let firstPoint = segment.0
            let secondPoint = segment.1
            let midpointY = (firstPoint.y + secondPoint.y) / 2
            guard midpointY <= topBandMaxY else {
                return false
            }

            let deltaX = secondPoint.x - firstPoint.x
            let deltaY = secondPoint.y - firstPoint.y
            let isBeamLike = abs(deltaX) >= max(CGFloat(3), abs(deltaY) * 1.15)
            let wideEnough = abs(deltaX) >= max(CGFloat(3), bounds.width * 0.18)
            return isBeamLike && wideEnough
        }
    }

    func isCompactMark(comparedTo referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(1, referenceBounds.height)
        let referenceWidth = max(1, referenceBounds.width)
        let compactWidth = bounds.width <= max(10, referenceWidth * 0.42)
        let compactHeight = bounds.height <= max(10, referenceHeight * 0.42)
        let shortPath = pathLength <= max(34, referenceHeight * 1.75)

        return compactWidth && compactHeight && shortPath
    }

    func looksLikeQuarterRestBody(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let coversRestHeight = bounds.height >= referenceHeight * 0.55
        let narrowEnough = bounds.width <= max(referenceBounds.width * 1.05, bounds.height * 1.35)
        let spansBody = bounds.minY <= referenceBounds.minY + referenceHeight * 0.24
            && bounds.maxY >= referenceBounds.maxY - referenceHeight * 0.18
        let hasHandwrittenZigZag = directionChangeCount >= 2
            || (directionChangeCount >= 1 && pathLength >= bounds.height * 1.12)
            || (bounds.width <= bounds.height * 0.5 && pathLength >= bounds.height * 1.08)
        let restShaped = bounds.height > bounds.width * 0.72 || directionChangeCount >= 2
        let upperHookSuggestsEighthRest = hasHorizontalUpperHook && directionChangeCount <= 2

        return coversRestHeight
            && narrowEnough
            && spansBody
            && hasHandwrittenZigZag
            && restShaped
            && !upperHookSuggestsEighthRest
            && !looksClosed
    }

    func looksLikeQuarterRestSegment(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let largeEnough = bounds.height >= referenceHeight * 0.18
            || bounds.width >= max(CGFloat(5), referenceBounds.width * 0.32)
        let angledOrCurved = directionChangeCount >= 1
            || (!isMostlyHorizontal && !isMostlyVertical)
            || pathLength >= max(CGFloat(8), hypot(bounds.width, bounds.height) * 1.0)

        return largeEnough
            && angledOrCurved
            && !looksClosed
            && !isCompactMark(comparedTo: referenceBounds)
    }

    func looksLikeEighthRestHook(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let referenceWidth = max(CGFloat(1), referenceBounds.width)
        if looksLikeEighthRestDot(in: referenceBounds) {
            return true
        }

        let compactEnough = bounds.width <= max(CGFloat(18), referenceWidth * 0.68)
            && bounds.height <= max(CGFloat(14), referenceHeight * 0.48)
        let upperLeftEnough = center.y <= referenceBounds.midY + referenceHeight * 0.2
            && center.x <= referenceBounds.midX + referenceWidth * 0.18
        let hookLike = isCompactMark(comparedTo: referenceBounds)
            || looksFilledNoteHead
            || directionChangeCount >= 1
            || bounds.width >= bounds.height * 0.72

        return compactEnough
            && upperLeftEnough
            && hookLike
            && (!looksClosed || looksFilledNoteHead)
    }

    func looksLikeSingleStrokeEighthRest(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let touchesUpperBody = bounds.minY <= referenceBounds.midY + referenceHeight * 0.1
        let reachesLowerBody = bounds.maxY >= referenceBounds.midY + referenceHeight * 0.18
            || bounds.maxY >= referenceBounds.maxY - referenceHeight * 0.12
        let hasHookOrLean = hasHorizontalUpperHook
            || directionChangeCount >= 1
            || bounds.width >= max(CGFloat(5), bounds.height * 0.18)
        let restSized = bounds.height >= max(CGFloat(8), referenceHeight * 0.42)
            && bounds.width <= max(CGFloat(28), referenceBounds.width * 1.12)

        return restSized
            && touchesUpperBody
            && reachesLowerBody
            && hasHookOrLean
            && !looksLikeQuarterRestBody(in: referenceBounds)
            && !looksClosed
    }

    func looksLikeEighthRestDot(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let referenceWidth = max(CGFloat(1), referenceBounds.width)
        let compactEnough = bounds.width <= max(CGFloat(10), referenceWidth * 0.42)
            && bounds.height <= max(CGFloat(10), referenceHeight * 0.36)
        let upperEnough = center.y <= referenceBounds.midY + referenceHeight * 0.04
        let notTooFarRight = center.x <= referenceBounds.midX + referenceWidth * 0.28
        let filledCircle = looksFilledNoteHead || (looksClosed && (looksDense || hasInteriorFillGesture))

        return compactEnough
            && upperEnough
            && notTooFarRight
            && filledCircle
    }

    func hasShortAngledRestLine(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let shortEnough = pathLength <= max(CGFloat(28), referenceHeight * 0.95)
        let upperEnough = center.y <= referenceBounds.midY + referenceHeight * 0.22
        let visibleEnough = bounds.width >= 3 && bounds.height >= 2

        return !looksClosed
            && shortEnough
            && upperEnough
            && visibleEnough
            && containsSegmentAngle(inDegrees: 20...80, minimumLength: 2.5)
    }

    func hasDownwardRestTail(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let referenceWidth = max(CGFloat(1), referenceBounds.width)
        let tallEnough = bounds.height >= max(CGFloat(8), referenceHeight * 0.34)
        let narrowEnough = bounds.width <= max(CGFloat(22), referenceWidth * 0.95)
        let reachesLowerBody = bounds.maxY >= referenceBounds.midY + referenceHeight * 0.14

        return !looksClosed
            && tallEnough
            && narrowEnough
            && reachesLowerBody
            && containsSegmentAngle(inDegrees: 45...90, minimumLength: 4)
    }

    func containsSegmentAngle(inDegrees angleRange: ClosedRange<CGFloat>, minimumLength: CGFloat) -> Bool {
        zip(points, points.dropFirst()).contains { firstPoint, secondPoint in
            let deltaX = secondPoint.x - firstPoint.x
            let deltaY = secondPoint.y - firstPoint.y
            let length = hypot(deltaX, deltaY)
            guard length >= minimumLength else {
                return false
            }

            let angle = atan2(abs(deltaY), abs(deltaX)) * 180 / .pi
            return angleRange.contains(angle)
        }
    }

    func looksLikeLowerNotehead(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let referenceWidth = max(CGFloat(1), referenceBounds.width)
        let separatedLowerBody = center.y >= referenceBounds.midY + referenceHeight * 0.06
            || bounds.maxY >= referenceBounds.maxY - referenceHeight * 0.18
        let noteheadSized = bounds.width >= max(CGFloat(7), referenceWidth * 0.12)
            && bounds.height >= max(CGFloat(5), referenceHeight * 0.1)
        let ovalOrDenseHead = looksClosed
            || (looksFilledNoteHead && bounds.width >= bounds.height * 0.5)
        let notStemOrTail = bounds.width >= bounds.height * 0.48

        return separatedLowerBody
            && noteheadSized
            && ovalOrDenseHead
            && notStemOrTail
    }
}

private struct RhythmCandidate: Hashable {
    let value: RhythmValue
    let score: Double

    var isConfidentEnoughForMeasureFit: Bool {
        score <= 1.15
    }
}

private struct CandidatePath: Hashable {
    let values: [RhythmValue]
    let score: Double
    let units: Int
}

private struct SymbolObservation: Hashable {
    let strokes: [StrokeObservation]
    let bounds: CGRect

    init(strokes: [StrokeObservation]) {
        self.strokes = strokes
        self.bounds = strokes.reduce(into: CGRect.null) { partialResult, stroke in
            partialResult = partialResult.union(stroke.bounds)
        }
    }
}

private extension SymbolObservation {
    func beamedEighthNoteCount(drawingFrame: CGRect) -> Int {
        guard strokes.count >= 3 else {
            return 0
        }

        let noteheadXs = beamedNoteheadXs(drawingFrame: drawingFrame)
        let stemXs = inferredStemXs(drawingFrame: drawingFrame)
        guard noteheadXs.count >= 2 || stemXs.count >= 2 else {
            return 0
        }

        if noteheadXs.count >= 2 {
            let hasEnoughStemInformation = stemXs.count >= 2
                || noteheadXs.allSatisfy { noteheadX in
                    stemXs.contains { abs($0 - noteheadX) <= max(CGFloat(8), drawingFrame.width * 0.045) }
                }
            guard hasEnoughStemInformation else {
                return 0
            }

            let beamedNoteheadXs = noteheadXs.filter { noteheadX in
                strokes.contains { stroke in
                    stroke.coversBeamedNotehead(at: noteheadX, noteheadXs: noteheadXs, in: bounds)
                }
            }
            if beamedNoteheadXs.count >= 2 {
                return min(beamedNoteheadXs.count, 4)
            }
        }

        let beamedStemXs = stemXs.filter { stemX in
            strokes.contains { stroke in
                stroke.coversBeamedNotehead(at: stemX, noteheadXs: stemXs, in: bounds)
            }
        }
        guard beamedStemXs.count >= 2 else {
            return 0
        }

        return min(beamedStemXs.count, 4)
    }

    func isSelfContainedBeamedEighthRun(drawingFrame: CGRect) -> Bool {
        let beamedCount = beamedEighthNoteCount(drawingFrame: drawingFrame)
        guard beamedCount >= 2 else {
            return false
        }

        let noteheadCount = beamedNoteheadXs(drawingFrame: drawingFrame).count
        let stemCount = inferredStemXs(drawingFrame: drawingFrame).count
        let anchorCount = max(noteheadCount, stemCount)
        return anchorCount == beamedCount
    }

    private func beamedNoteheadXs(drawingFrame: CGRect) -> [CGFloat] {
        let symbolHeight = max(CGFloat(1), bounds.height)
        let lowerBandY = bounds.minY + symbolHeight * 0.43
        let maxHeadWidth = max(CGFloat(18), drawingFrame.width * 0.09)
        let maxHeadHeight = max(CGFloat(18), symbolHeight * 0.58)
        let candidates = strokes.compactMap { stroke -> CGFloat? in
            let sitsInHeadBand = stroke.bounds.maxY >= lowerBandY
                || stroke.center.y >= bounds.midY - symbolHeight * 0.12
            let compactEnough = stroke.bounds.width <= maxHeadWidth
                && stroke.bounds.height <= maxHeadHeight
            let readsAsHead = stroke.looksFilledNoteHead
                || stroke.looksClosed
                || (stroke.looksDense && stroke.bounds.width >= 3 && stroke.bounds.height >= 3)

            return sitsInHeadBand && compactEnough && readsAsHead ? stroke.center.x : nil
        }

        return candidates.clusteredXs(minimumSeparation: max(CGFloat(8), drawingFrame.width * 0.035))
    }

    private func inferredStemXs(drawingFrame: CGRect) -> [CGFloat] {
        let symbolHeight = max(CGFloat(1), bounds.height)
        let directStems = strokes.compactMap { stroke -> CGFloat? in
            let verticalEnough = stroke.bounds.height >= max(CGFloat(10), symbolHeight * 0.36)
            let narrowEnough = stroke.bounds.width <= max(CGFloat(10), stroke.bounds.height * 0.62)
            let touchesLowerBody = stroke.bounds.maxY >= bounds.minY + symbolHeight * 0.42

            return verticalEnough && narrowEnough && touchesLowerBody && !stroke.looksClosed
                ? stroke.bounds.midX
                : nil
        }

        let connectedStemXs = strokes.flatMap { stroke in
            stroke.connectedBeamStemXs(in: bounds)
        }

        return (directStems + connectedStemXs)
            .clusteredXs(minimumSeparation: max(CGFloat(8), drawingFrame.width * 0.035))
    }
}

private extension Array where Element == [StrokeObservation] {
    func mergingLooseDots(drawingFrame: CGRect) -> [[StrokeObservation]] {
        var mergedGroups: [[StrokeObservation]] = []
        let dotSizeLimit = Swift.max(CGFloat(5), Swift.min(CGFloat(9), drawingFrame.height * 0.1))
        let mergeGapLimit = Swift.max(CGFloat(36), drawingFrame.width * 0.17)
        let verticalLimit = Swift.max(CGFloat(24), drawingFrame.height * 0.5)

        for group in self {
            guard let groupBounds = group.nonEmptyBounds else {
                continue
            }

            let isLooseDotGroup = group.count <= 2
                && groupBounds.width <= dotSizeLimit
                && groupBounds.height <= dotSizeLimit

            if isLooseDotGroup,
               var previousGroup = mergedGroups.popLast(),
               let previousBounds = previousGroup.nonEmptyBounds {
                let horizontalGap = groupBounds.minX - previousBounds.maxX
                let verticalDistance = abs(groupBounds.midY - previousBounds.midY)
                let shouldMergeAsDottedRhythm = horizontalGap >= -dotSizeLimit
                    && horizontalGap <= mergeGapLimit
                    && verticalDistance <= verticalLimit
                    && groupBounds.midX >= previousBounds.midX

                if shouldMergeAsDottedRhythm {
                    previousGroup.append(contentsOf: group)
                    mergedGroups.append(previousGroup)
                    continue
                }

                mergedGroups.append(previousGroup)
            }

            mergedGroups.append(group)
        }

        return mergedGroups
    }

    func splittingCompoundStemmedSymbols(drawingFrame: CGRect) -> [[StrokeObservation]] {
        flatMap { group -> [[StrokeObservation]] in
            if SymbolObservation(strokes: group).isSelfContainedBeamedEighthRun(drawingFrame: drawingFrame) {
                return [group]
            }

            let stemAnchors = group.stemAnchorStrokes(drawingFrame: drawingFrame)
            guard stemAnchors.count > 1 else {
                return [group]
            }

            var buckets = stemAnchors.map { [$0] }
            for stroke in group where !stemAnchors.contains(stroke) {
                if stroke.isSharedBeam(across: stemAnchors),
                   let firstCoveredIndex = stemAnchors.firstIndex(where: { stroke.bounds.minX <= $0.bounds.midX && stroke.bounds.maxX >= $0.bounds.midX }) {
                    for index in firstCoveredIndex..<stemAnchors.count
                    where stroke.bounds.minX <= stemAnchors[index].bounds.midX
                        && stroke.bounds.maxX >= stemAnchors[index].bounds.midX {
                        buckets[index].append(stroke)
                    }
                    continue
                }

                let targetIndex: Int
                if stroke.isDotLike(in: group.nonEmptyBounds ?? stroke.bounds),
                   !stroke.looksLikeLowerNotehead(in: group.nonEmptyBounds ?? stroke.bounds),
                   let previousStemIndex = stemAnchors.lastIndex(where: { $0.bounds.midX < stroke.center.x }) {
                    targetIndex = previousStemIndex
                } else {
                    targetIndex = stemAnchors.nearestIndex(toX: stroke.center.x) ?? 0
                }

                buckets[targetIndex].append(stroke)
            }

            return buckets
                .filter { !$0.isEmpty }
                .sorted { lhs, rhs in
                    (lhs.nonEmptyBounds?.minX ?? 0) < (rhs.nonEmptyBounds?.minX ?? 0)
                }
        }
    }

    func reattachingLeadingNoteheadsToFollowingBeams(drawingFrame: CGRect) -> [[StrokeObservation]] {
        var resolvedGroups: [[StrokeObservation]] = []
        var index = 0

        while index < count {
            guard index + 1 < count,
                  let currentBounds = self[index].nonEmptyBounds,
                  let nextBounds = self[index + 1].nonEmptyBounds,
                  self[index].isLooseNoteheadOnly(drawingFrame: drawingFrame),
                  SymbolObservation(strokes: self[index + 1]).beamedEighthNoteCount(drawingFrame: drawingFrame) >= 2 else {
                resolvedGroups.append(self[index])
                index += 1
                continue
            }

            let horizontalGap = nextBounds.minX - currentBounds.maxX
            let allowedGap = Swift.max(CGFloat(6), Swift.min(CGFloat(14), drawingFrame.width * 0.045))
            let verticallyBelongsToBeamGroup = currentBounds.midY >= nextBounds.midY - nextBounds.height * 0.15
                && currentBounds.midY <= nextBounds.maxY + nextBounds.height * 0.25

            if horizontalGap <= allowedGap,
               currentBounds.midX < nextBounds.midX,
               verticallyBelongsToBeamGroup {
                resolvedGroups.append(self[index] + self[index + 1])
                index += 2
            } else {
                resolvedGroups.append(self[index])
                index += 1
            }
        }

        return resolvedGroups
    }

    func reattachingLeadingDotsToPreviousSymbols(drawingFrame: CGRect) -> [[StrokeObservation]] {
        reduce(into: [[StrokeObservation]]()) { resolvedGroups, group in
            guard !resolvedGroups.isEmpty,
                  let groupBounds = group.nonEmptyBounds,
                  let firstStem = group.stemAnchorStrokes(drawingFrame: drawingFrame).first else {
                resolvedGroups.append(group)
                return
            }

            let movableDots = group.filter { stroke in
                stroke.isDotLike(in: groupBounds)
                    && stroke.bounds.maxX < firstStem.bounds.midX
                    && stroke.center.y >= groupBounds.midY - groupBounds.height * 0.12
            }
            guard !movableDots.isEmpty else {
                resolvedGroups.append(group)
                return
            }

            let remainingStrokes = group.filter { !movableDots.contains($0) }
            resolvedGroups[resolvedGroups.count - 1].append(contentsOf: movableDots)

            if !remainingStrokes.isEmpty {
                resolvedGroups.append(remainingStrokes)
            }
        }
    }
}

private extension Array where Element == StrokeObservation {
    func stemAnchorStrokes(drawingFrame: CGRect) -> [StrokeObservation] {
        guard let groupBounds = nonEmptyBounds else {
            return []
        }

        let groupHeight = Swift.max(CGFloat(1), groupBounds.height)
        let stemCandidates = filter { stroke in
            let verticalEnough = stroke.bounds.height >= Swift.max(10, groupHeight * 0.42)
            let narrowEnough = stroke.bounds.width <= Swift.max(10, stroke.bounds.height * 0.58)
            let hasStemGesture = stroke.isMostlyVertical
                || stroke.looksLikeSingleStrokeEighthNote
                || (verticalEnough && stroke.pathLength <= stroke.bounds.height * 2.35)

            return verticalEnough
                && narrowEnough
                && hasStemGesture
                && !stroke.looksClosed
                && !stroke.isDotLike(in: groupBounds)
        }

        let minimumSeparation = Swift.max(CGFloat(7), drawingFrame.width * 0.04)
        return stemCandidates
            .sorted { lhs, rhs in
                if abs(lhs.bounds.midX - rhs.bounds.midX) > 0.5 {
                    return lhs.bounds.midX < rhs.bounds.midX
                }
                return lhs.bounds.height > rhs.bounds.height
            }
            .reduce(into: [StrokeObservation]()) { anchors, candidate in
                guard !anchors.contains(where: { abs($0.bounds.midX - candidate.bounds.midX) < minimumSeparation }) else {
                    return
                }
                anchors.append(candidate)
            }
    }

    func nearestIndex(toX x: CGFloat) -> Int? {
        indices.min { lhs, rhs in
            abs(self[lhs].bounds.midX - x) < abs(self[rhs].bounds.midX - x)
        }
    }
}

private extension StrokeObservation {
    func isDotLike(in referenceBounds: CGRect) -> Bool {
        let referenceHeight = max(CGFloat(1), referenceBounds.height)
        let referenceWidth = max(CGFloat(1), referenceBounds.width)
        return bounds.width <= max(10, referenceWidth * 0.34)
            && bounds.height <= max(10, referenceHeight * 0.34)
            && pathLength <= max(36, referenceHeight * 1.8)
    }

    func isSharedBeam(across stems: [StrokeObservation]) -> Bool {
        guard stems.count > 1,
              isMostlyHorizontal,
              bounds.height <= max(7, bounds.width * 0.35) else {
            return false
        }

        let coverageTolerance = max(CGFloat(8), bounds.width * 0.25)
        let coveredStemCount = stems.filter { stem in
            bounds.minX <= stem.bounds.midX + coverageTolerance
                && bounds.maxX >= stem.bounds.midX - coverageTolerance
        }.count
        return coveredStemCount > 1
    }

    func isSharedBeam(overNoteheadXs noteheadXs: [CGFloat], in symbolBounds: CGRect) -> Bool {
        guard noteheadXs.count >= 2,
              bounds.width >= max(CGFloat(12), symbolBounds.height * 0.24),
              bounds.height <= max(CGFloat(9), symbolBounds.height * 0.28),
              bounds.midY <= symbolBounds.minY + symbolBounds.height * 0.42 else {
            return false
        }

        let coverageTolerance = beamedCoverageTolerance(in: symbolBounds)
        let coveredHeadCount = noteheadXs.filter { noteheadX in
            bounds.minX <= noteheadX + coverageTolerance
                && bounds.maxX >= noteheadX - coverageTolerance
        }.count
        return coveredHeadCount >= 2
    }

    func coversBeamedNotehead(
        at noteheadX: CGFloat,
        noteheadXs: [CGFloat],
        in symbolBounds: CGRect
    ) -> Bool {
        if isSharedBeam(overNoteheadXs: noteheadXs, in: symbolBounds) {
            let coverageTolerance = beamedCoverageTolerance(in: symbolBounds)
            return bounds.minX <= noteheadX + coverageTolerance
                && bounds.maxX >= noteheadX - coverageTolerance
        }

        guard isConnectedBeamFrame(overNoteheadXs: noteheadXs, in: symbolBounds) else {
            return false
        }

        return connectedBeamStemXs(in: symbolBounds).contains { stemX in
            abs(stemX - noteheadX) <= max(CGFloat(10), symbolBounds.width * 0.18)
        }
    }

    func isConnectedBeamFrame(overNoteheadXs noteheadXs: [CGFloat], in symbolBounds: CGRect) -> Bool {
        guard noteheadXs.count >= 2,
              bounds.width >= max(CGFloat(12), symbolBounds.height * 0.24),
              bounds.height >= max(CGFloat(10), symbolBounds.height * 0.48) else {
            return false
        }

        let topBandMaxY = symbolBounds.minY + symbolBounds.height * 0.38
        let lowerBandMinY = symbolBounds.minY + symbolBounds.height * 0.46
        let topPoints = points.filter { $0.y <= topBandMaxY }
        guard topPoints.xSpread >= max(CGFloat(12), symbolBounds.width * 0.34) else {
            return false
        }

        let stemXs = connectedBeamStemXs(in: symbolBounds)
        guard stemXs.count >= 2 else {
            return false
        }

        let coveredHeadCount = noteheadXs.filter { noteheadX in
            stemXs.contains { abs($0 - noteheadX) <= max(CGFloat(12), symbolBounds.width * 0.22) }
        }.count
        let hasLowerStemPoints = points.contains { $0.y >= lowerBandMinY }
        return coveredHeadCount >= 2 && hasLowerStemPoints
    }

    func connectedBeamStemXs(in symbolBounds: CGRect) -> [CGFloat] {
        guard bounds.width >= max(CGFloat(10), symbolBounds.width * 0.22),
              bounds.height >= max(CGFloat(10), symbolBounds.height * 0.38) else {
            return []
        }

        let lowerBandMinY = symbolBounds.minY + symbolBounds.height * 0.45
        let lowerPoints = points.filter { $0.y >= lowerBandMinY }
        return lowerPoints.map(\.x)
            .clusteredXs(minimumSeparation: max(CGFloat(7), symbolBounds.width * 0.14))
    }

    func beamedCoverageTolerance(in symbolBounds: CGRect) -> CGFloat {
        max(CGFloat(8), symbolBounds.width * 0.14)
    }
}

private struct SymbolFeatures {
    let symbol: SymbolObservation
    let contentStrokes: [StrokeObservation]
    let dotStrokes: [StrokeObservation]
    let contentBounds: CGRect
    let stemStroke: StrokeObservation?
    let flagStrokes: [StrokeObservation]
    let headStrokes: [StrokeObservation]

    init(symbol: SymbolObservation, drawingFrame: CGRect) {
        self.symbol = symbol
        let initialBody = symbol.strokes.filter { stroke in
            let relaxedDotSize = stroke.bounds.width <= max(14, symbol.bounds.width * 0.36)
                && stroke.bounds.height <= max(14, symbol.bounds.height * 0.36)
            return !stroke.isCompactMark(comparedTo: symbol.bounds) && !relaxedDotSize
                || stroke.center.x <= symbol.bounds.midX
        }
        let bodyBounds = initialBody.nonEmptyBounds ?? symbol.bounds
        let likelyStemStrokes = symbol.strokes.filter { stroke in
            stroke.bounds.height >= max(10, bodyBounds.height * 0.38)
                && stroke.bounds.width <= max(10, stroke.bounds.height * 0.58)
                && !stroke.isDotLike(in: bodyBounds)
        }
        let likelyHasStem = !likelyStemStrokes.isEmpty
        let localDotStrokes = symbol.strokes.filter { stroke in
            let relaxedDotSize = stroke.bounds.width <= max(14, bodyBounds.width * 0.62)
                && stroke.bounds.height <= max(14, bodyBounds.height * 0.62)
                && stroke.pathLength <= max(40, bodyBounds.height * 2.2)
            let dotLike = stroke.isCompactMark(comparedTo: bodyBounds) || relaxedDotSize
            let rightOfBody = stroke.bounds.minX >= bodyBounds.minX + bodyBounds.width * 0.34
                && stroke.center.x >= bodyBounds.midX - bodyBounds.width * 0.08
            let nearBodyVertically = stroke.center.y >= bodyBounds.minY - bodyBounds.height * 0.2
                && stroke.center.y <= bodyBounds.maxY + bodyBounds.height * 0.55
            let sitsInNoteheadDotBand = !likelyHasStem
                || stroke.center.y >= bodyBounds.minY + bodyBounds.height * 0.38
            let protectsTopFlag = likelyHasStem
                && stroke.center.y < bodyBounds.minY + bodyBounds.height * 0.42
                && stroke.center.x >= bodyBounds.midX - bodyBounds.width * 0.08

            return dotLike
                && rightOfBody
                && nearBodyVertically
                && sitsInNoteheadDotBand
                && !protectsTopFlag
        }
        let localContentStrokes = symbol.strokes.filter { stroke in
            !localDotStrokes.contains(stroke)
        }
        let localContentBounds = localContentStrokes.nonEmptyBounds ?? symbol.bounds

        let symbolHeight = max(1, localContentBounds.height)
        let stemCandidates = localContentStrokes.filter { stroke in
            stroke.bounds.height >= max(9, symbolHeight * 0.38)
                && stroke.bounds.width <= max(9, stroke.bounds.height * 0.48)
                && stroke.bounds.maxY >= localContentBounds.minY + symbolHeight * 0.45
        }
        let localStemStroke = stemCandidates.max { lhs, rhs in
            lhs.bounds.height < rhs.bounds.height
        }

        let localFlagStrokes: [StrokeObservation]
        let localHeadStrokes: [StrokeObservation]
        if let localStemStroke {
            localFlagStrokes = localContentStrokes.filter { stroke in
                let isLikelyDot = stroke.isCompactMark(comparedTo: localContentBounds)
                    && stroke.center.x > localStemStroke.bounds.maxX
                    && stroke.center.y > localContentBounds.minY + symbolHeight * 0.38
                let nearStemTop = stroke.bounds.minY <= localStemStroke.bounds.minY + symbolHeight * 0.62
                    && stroke.center.y <= localContentBounds.midY + symbolHeight * 0.08
                let closeToStem = stroke.bounds.minX <= localStemStroke.bounds.maxX + symbolHeight * 0.42
                    && stroke.bounds.maxX >= localStemStroke.bounds.minX - symbolHeight * 0.16
                let flagLikeShape = stroke.bounds.width >= max(3, symbolHeight * 0.08)
                    || stroke.bounds.height >= max(5, symbolHeight * 0.16)
                    || stroke.directionChangeCount >= 1

                return stroke != localStemStroke
                    && !isLikelyDot
                    && nearStemTop
                    && closeToStem
                    && flagLikeShape
                    && stroke.bounds.height <= max(symbolHeight * 0.75, 18)
            }
            localHeadStrokes = localContentStrokes.filter { stroke in
                stroke != localStemStroke
                    && !localFlagStrokes.contains(stroke)
                    && stroke.center.y >= localContentBounds.minY + symbolHeight * 0.32
            }
        } else {
            localFlagStrokes = []
            localHeadStrokes = localContentStrokes
        }

        self.dotStrokes = localDotStrokes
        self.contentStrokes = localContentStrokes
        self.contentBounds = localContentBounds
        self.stemStroke = localStemStroke
        self.flagStrokes = localFlagStrokes
        self.headStrokes = localHeadStrokes
    }

    var hasDot: Bool {
        !dotStrokes.isEmpty
    }

    var hasStem: Bool {
        stemStroke != nil
    }

    var hasFlag: Bool {
        !flagStrokes.isEmpty || hasSingleStrokeFlagGesture
    }

    var hasSingleStrokeFlagGesture: Bool {
        contentStrokes.contains { stroke in
            stroke.looksLikeSingleStrokeEighthNote
                && stroke.bounds.minY <= contentBounds.minY + height * 0.22
        }
    }

    var width: CGFloat {
        max(1, contentBounds.width)
    }

    var height: CGFloat {
        max(1, contentBounds.height)
    }

    var hasHollowHead: Bool {
        headStrokes.contains { stroke in
            stroke.looksHollowNoteHead
        }
    }

    var hasFilledHead: Bool {
        headStrokes.contains { stroke in
            stroke.looksFilledNoteHead
                && stroke.bounds.width >= max(4, width * 0.14)
                && stroke.bounds.height >= max(4, height * 0.14)
                && stroke.center.y >= contentBounds.midY - height * 0.2
        }
    }

    var hasLowerHeadMass: Bool {
        headStrokes.contains { stroke in
            stroke.center.y >= contentBounds.midY
                && stroke.bounds.width >= max(4, width * 0.12)
                && stroke.bounds.height >= max(4, height * 0.12)
        }
    }

    var hasStemAndKick: Bool {
        guard let stemStroke else {
            return false
        }

        return contentStrokes.contains { stroke in
            stroke != stemStroke
                && stroke.center.y >= stemStroke.bounds.midY
                && stroke.bounds.maxX >= stemStroke.bounds.minX - width * 0.2
                && stroke.bounds.minX <= stemStroke.bounds.midX + width * 0.18
                && stroke.bounds.width > stroke.bounds.height * 0.45
        } || (contentStrokes.count == 1 && stemStroke.pathLength > stemStroke.bounds.height * 1.12)
    }

    var prefersEighthRestGesture: Bool {
        contentStrokes.contains { stroke in
            stroke.hasHorizontalUpperHook && stroke.directionChangeCount <= 2
        }
    }

    var hasStandardEighthRestGesture: Bool {
        let hasSmallFilledCircle = contentStrokes.contains { stroke in
            stroke.looksLikeEighthRestDot(in: contentBounds)
        }
        let hasShortAngledLine = contentStrokes.contains { stroke in
            !stroke.looksLikeEighthRestDot(in: contentBounds)
                && stroke.hasShortAngledRestLine(in: contentBounds)
        }
        let hasDownwardStroke = contentStrokes.contains { stroke in
            !stroke.looksLikeEighthRestDot(in: contentBounds)
                && stroke.hasDownwardRestTail(in: contentBounds)
        }

        return hasSmallFilledCircle
            && hasShortAngledLine
            && hasDownwardStroke
            && !hasDefiniteLowerNotehead
    }

    var hasDefiniteLowerNotehead: Bool {
        contentStrokes.contains { stroke in
            stroke.looksLikeLowerNotehead(in: contentBounds)
        }
    }

    var hasClearNoteGlyph: Bool {
        guard hasStem else {
            return false
        }

        if hasDefiniteLowerNotehead {
            return true
        }

        return headStrokes.contains { stroke in
            let separatedLowerBody = stroke.center.y >= contentBounds.midY + height * 0.04
                || stroke.bounds.maxY >= contentBounds.maxY - height * 0.22
            let noteheadSized = stroke.bounds.width >= max(CGFloat(4), width * 0.14)
                && stroke.bounds.height >= max(CGFloat(4), height * 0.12)
            let ovalOrDenseHead = stroke.looksClosed
                || stroke.looksHollowNoteHead
                || (stroke.looksFilledNoteHead && stroke.bounds.width >= stroke.bounds.height * 0.55)

            return separatedLowerBody && noteheadSized && ovalOrDenseHead
        }
    }
}

private extension Array where Element == StrokeObservation {
    func isLooseNoteheadOnly(drawingFrame: CGRect) -> Bool {
        guard let bounds = nonEmptyBounds,
              !isEmpty,
              count <= 2,
              bounds.width >= Swift.max(CGFloat(5), drawingFrame.width * 0.018),
              bounds.height >= Swift.max(CGFloat(5), drawingFrame.height * 0.055),
              bounds.width <= Swift.max(CGFloat(18), drawingFrame.width * 0.09),
              bounds.height <= Swift.max(CGFloat(18), drawingFrame.height * 0.24) else {
            return false
        }

        return allSatisfy { stroke in
            stroke.looksFilledNoteHead || stroke.looksClosed
        }
    }

    var nonEmptyBounds: CGRect? {
        guard !isEmpty else {
            return nil
        }

        return reduce(into: CGRect.null) { partialResult, stroke in
            partialResult = partialResult.union(stroke.bounds)
        }
    }
}

private extension Array where Element == CGPoint {
    var xSpread: CGFloat {
        guard let first else {
            return 0
        }

        let range = reduce((minX: first.x, maxX: first.x)) { partialResult, point in
            (
                minX: Swift.min(partialResult.minX, point.x),
                maxX: Swift.max(partialResult.maxX, point.x)
            )
        }
        return range.maxX - range.minX
    }
}

private extension Array where Element == CGFloat {
    func clusteredXs(minimumSeparation: CGFloat) -> [CGFloat] {
        sorted().reduce(into: [CGFloat]()) { clusters, value in
            guard let previous = clusters.last else {
                clusters.append(value)
                return
            }

            if abs(value - previous) < minimumSeparation {
                clusters[clusters.count - 1] = (previous + value) / 2
            } else {
                clusters.append(value)
            }
        }
    }
}
#endif
