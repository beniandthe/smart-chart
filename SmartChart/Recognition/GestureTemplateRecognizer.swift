import Foundation

struct GestureTemplate: Hashable {
    var text: String
    var strokes: [InkStroke]

    init(text: String, strokes: [InkStroke]) {
        self.text = text
        self.strokes = strokes
    }
}

struct GestureTemplateRecognizerConfiguration: Hashable {
    var samplePointCount: Int
    var aspectRatioWeight: Double
    var strokeCountWeight: Double

    static let chordGlyphs = GestureTemplateRecognizerConfiguration(
        samplePointCount: 48,
        aspectRatioWeight: 0.18,
        strokeCountWeight: 0.12
    )
}

struct GestureTemplateRecognizer {
    var configuration: GestureTemplateRecognizerConfiguration

    init(configuration: GestureTemplateRecognizerConfiguration = .chordGlyphs) {
        self.configuration = configuration
    }

    func rankedCandidates(
        for cluster: InkCluster,
        templates: [GestureTemplate],
        limit: Int? = nil
    ) -> [GlyphCandidate] {
        guard let normalizedInput = NormalizedGesture(
            strokes: cluster.strokes,
            samplePointCount: configuration.samplePointCount
        ) else {
            return []
        }

        var candidatesByText = templates.reduce(into: [String: GlyphCandidate]()) { bestCandidates, template in
            guard let normalizedTemplate = NormalizedGesture(
                strokes: template.strokes,
                samplePointCount: configuration.samplePointCount
            ) else {
                return
            }

            let distance = distance(from: normalizedInput, to: normalizedTemplate)
            let confidence = 1 / (1 + distance * 2.4)
            let candidate = GlyphCandidate(
                text: template.text,
                confidence: confidence,
                source: .template
            )

            if let currentBestCandidate = bestCandidates[template.text],
               currentBestCandidate.confidence >= candidate.confidence {
                return
            }

            bestCandidates[template.text] = candidate
        }

        for candidate in heuristicCandidates(for: cluster) {
            if let currentBestCandidate = candidatesByText[candidate.text],
               currentBestCandidate.confidence >= candidate.confidence {
                continue
            }

            candidatesByText[candidate.text] = candidate
        }

        let candidates = candidatesByText.values.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }

            return lhs.text < rhs.text
        }

        if let limit {
            return Array(candidates.prefix(limit))
        }

        return candidates
    }

    private func heuristicCandidates(for cluster: InkCluster) -> [GlyphCandidate] {
        let features = RootGlyphFeatures(cluster: cluster)
        var candidates = accidentalCandidates(features)

        switch features.strokeCount {
        case 1:
            candidates += oneStrokeRootCandidates(features)
        case 2:
            candidates += twoStrokeRootCandidates(features)
        case 3:
            candidates += threeStrokeRootCandidates(features)
        default:
            break
        }

        return candidates
    }

    private func accidentalCandidates(_ features: RootGlyphFeatures) -> [GlyphCandidate] {
        var candidates: [GlyphCandidate] = []

        if isSharpLike(features) {
            candidates.append(heuristicCandidate("#", confidence: 0.99))
        }

        if isFlatLike(features) {
            candidates.append(heuristicCandidate("b", confidence: 0.98))
        }

        return candidates
    }

    private func isSharpLike(_ features: RootGlyphFeatures) -> Bool {
        features.strokeCount >= 4
            && features.strokeCount <= 6
            && features.looseVerticalStrokeCount >= 2
            && features.looseHorizontalStrokeCount >= 1
            && features.aspectRatio >= 0.35
            && features.aspectRatio <= 1.20
    }

    private func isFlatLike(_ features: RootGlyphFeatures) -> Bool {
        if features.strokeCount == 1,
           let stroke = features.strokes.first,
           stroke.pointCount >= 14,
           stroke.bounds.height >= 14,
           stroke.aspectRatio >= 0.55,
           stroke.aspectRatio <= 1.10,
           stroke.straightness >= 0.25,
           stroke.straightness <= 0.58,
           stroke.angleDegrees >= 55,
           stroke.angleDegrees <= 90 {
            return true
        }

        if features.strokeCount == 2,
           features.hasLooseVerticalStroke,
           let curvedStroke = features.strokes
            .filter({ !$0.isLooseVertical })
            .max(by: { $0.pathLength < $1.pathLength }),
           curvedStroke.pointCount >= 8,
           curvedStroke.straightness <= 0.45,
           features.aspectRatio >= 0.45,
           features.aspectRatio <= 1.35 {
            return true
        }

        return false
    }

    private func oneStrokeRootCandidates(_ features: RootGlyphFeatures) -> [GlyphCandidate] {
        guard let stroke = features.strokes.first,
              stroke.bounds.height >= 8,
              stroke.bounds.width >= 4,
              stroke.straightness < 0.65 else {
            return []
        }

        if stroke.straightness < 0.35 {
            return [heuristicCandidate("G", confidence: 0.97)]
        }

        if stroke.straightness >= 0.35 && stroke.endPoint.y > features.bounds.recognitionMidY {
            return [heuristicCandidate("C", confidence: 0.95)]
        }

        return []
    }

    private func twoStrokeRootCandidates(_ features: RootGlyphFeatures) -> [GlyphCandidate] {
        if features.hasHorizontalStroke,
           !features.hasVerticalStem,
           let mainStroke = features.strokes.max(by: { $0.pathLength < $1.pathLength }),
           mainStroke.straightness < 0.45,
           features.aspectRatio >= 0.50,
           features.aspectRatio <= 0.95 {
            return [heuristicCandidate("A", confidence: 0.98)]
        }

        if features.hasVerticalStem,
           let bodyStroke = features.strokes
            .filter({ !$0.isVerticalStem })
            .max(by: { $0.pathLength < $1.pathLength }) {
            if bodyStroke.pointCount >= 18 && bodyStroke.straightness < 0.55 {
                return [heuristicCandidate("B", confidence: 0.97)]
            }

            if isDLikeBody(bodyStroke, in: features) {
                return [heuristicCandidate("D", confidence: 0.96)]
            }
        }

        return []
    }

    private func isDLikeBody(_ bodyStroke: RootStrokeFeatures, in features: RootGlyphFeatures) -> Bool {
        if bodyStroke.pointCount <= 14,
           features.aspectRatio >= 0.55,
           bodyStroke.straightness >= 0.38,
           bodyStroke.straightness < 0.82 {
            return true
        }

        if features.aspectRatio >= 0.90,
           bodyStroke.aspectRatio >= 0.90,
           bodyStroke.pointCount <= 18,
           bodyStroke.straightness < 0.60 {
            return true
        }

        return false
    }

    private func threeStrokeRootCandidates(_ features: RootGlyphFeatures) -> [GlyphCandidate] {
        guard features.aspectRatio >= 0.45,
              features.aspectRatio <= 1.05 else {
            return []
        }

        if features.hasVerticalStem && features.horizontalStrokeCount >= 2 {
            return [heuristicCandidate("F", confidence: 0.96)]
        }

        if !features.hasVerticalStem && features.horizontalStrokeCount >= 1 {
            return [heuristicCandidate("E", confidence: 0.98)]
        }

        return []
    }

    private func heuristicCandidate(_ text: String, confidence: Double) -> GlyphCandidate {
        GlyphCandidate(text: text, confidence: confidence, source: .heuristic)
    }

    private func distance(
        from input: NormalizedGesture,
        to template: NormalizedGesture
    ) -> Double {
        let pointDistance = zip(input.points, template.points)
            .map { lhs, rhs in
                lhs.distance(to: rhs)
            }
            .reduce(0, +) / Double(max(input.points.count, 1))

        let aspectPenalty = abs(log(input.aspectRatio / template.aspectRatio))
            * configuration.aspectRatioWeight
        let strokeCountPenalty = Double(abs(input.strokeCount - template.strokeCount))
            / Double(max(input.strokeCount, template.strokeCount, 1))
            * configuration.strokeCountWeight

        return pointDistance + aspectPenalty + strokeCountPenalty
    }
}

private struct RootGlyphFeatures: Hashable {
    var strokes: [RootStrokeFeatures]
    var bounds: InkBounds

    init(cluster: InkCluster) {
        strokes = cluster.strokes.map(RootStrokeFeatures.init(stroke:))
        bounds = cluster.bounds
    }

    var strokeCount: Int {
        strokes.count
    }

    var aspectRatio: Double {
        max(bounds.width, 1) / max(bounds.height, 1)
    }

    var hasHorizontalStroke: Bool {
        horizontalStrokeCount > 0
    }

    var horizontalStrokeCount: Int {
        strokes.filter(\.isHorizontal).count
    }

    var looseHorizontalStrokeCount: Int {
        strokes.filter(\.isLooseHorizontal).count
    }

    var looseVerticalStrokeCount: Int {
        strokes.filter(\.isLooseVertical).count
    }

    var hasLooseVerticalStroke: Bool {
        looseVerticalStrokeCount > 0
    }

    var hasVerticalStem: Bool {
        strokes.contains(where: \.isVerticalStem)
    }
}

private extension InkBounds {
    var recognitionMidY: Double {
        minY + height / 2
    }
}

private struct RootStrokeFeatures: Hashable {
    var bounds: InkBounds
    var startPoint: InkPoint
    var endPoint: InkPoint
    var pathLength: Double
    var pointCount: Int
    var straightness: Double
    var angleDegrees: Double

    init(stroke: InkStroke) {
        bounds = stroke.bounds
        startPoint = stroke.points.first ?? InkPoint(x: 0, y: 0, timeOffset: nil)
        endPoint = stroke.points.last ?? startPoint
        pointCount = stroke.points.count
        pathLength = zip(stroke.points, stroke.points.dropFirst())
            .map { start, end in
                start.distance(to: end)
            }
            .reduce(0, +)

        let directDistance = startPoint.distance(to: endPoint)
        straightness = pathLength > 0 ? directDistance / pathLength : 0
        angleDegrees = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x) * 180 / .pi
    }

    var isHorizontal: Bool {
        bounds.width >= 6
            && bounds.width / max(bounds.height, 1) >= 2.0
            && abs(angleDegrees) <= 35
            && straightness >= 0.55
    }

    var isLooseHorizontal: Bool {
        bounds.width >= 6
            && bounds.width / max(bounds.height, 1) >= 1.65
            && abs(angleDegrees) <= 45
    }

    var isLooseVertical: Bool {
        bounds.height >= 8
            && bounds.height / max(bounds.width, 1) >= 1.8
            && abs(abs(angleDegrees) - 90) <= 35
    }

    var isVerticalStem: Bool {
        bounds.height >= 8
            && bounds.height / max(bounds.width, 1) >= 2.4
            && abs(abs(angleDegrees) - 90) <= 25
            && straightness >= 0.75
    }

    var aspectRatio: Double {
        max(bounds.width, 1) / max(bounds.height, 1)
    }
}

private struct NormalizedGesture: Hashable {
    var points: [NormalizedPoint]
    var aspectRatio: Double
    var strokeCount: Int

    init?(strokes: [InkStroke], samplePointCount: Int) {
        let rawPoints = strokes.flatMap(\.points)
        guard !rawPoints.isEmpty else {
            return nil
        }

        let bounds = InkBounds.enclosing(rawPoints)
        let sampledPoints = Self.resampled(rawPoints, count: max(2, samplePointCount))
        let scale = max(bounds.width, bounds.height, 1)
        let scaledPoints = sampledPoints.map { point in
            NormalizedPoint(
                x: (point.x - bounds.minX) / scale,
                y: (point.y - bounds.minY) / scale
            )
        }
        let centroid = NormalizedPoint.centroid(of: scaledPoints)

        points = scaledPoints.map { point in
            NormalizedPoint(
                x: point.x - centroid.x,
                y: point.y - centroid.y
            )
        }
        aspectRatio = max(bounds.width, 1) / max(bounds.height, 1)
        strokeCount = strokes.count
    }

    private static func resampled(_ points: [InkPoint], count: Int) -> [InkPoint] {
        guard let firstPoint = points.first else {
            return []
        }

        guard points.count > 1 else {
            return Array(repeating: firstPoint, count: count)
        }

        let pathLength = zip(points, points.dropFirst())
            .map { start, end in
                start.distance(to: end)
            }
            .reduce(0, +)

        guard pathLength > 0 else {
            return Array(repeating: firstPoint, count: count)
        }

        let interval = pathLength / Double(count - 1)
        var sampledPoints = [firstPoint]
        var distanceSinceLastSample = 0.0
        var previousPoint = firstPoint
        var sourceIndex = points.index(after: points.startIndex)

        while sourceIndex < points.endIndex,
              sampledPoints.count < count {
            let currentPoint = points[sourceIndex]
            let segmentLength = previousPoint.distance(to: currentPoint)

            guard segmentLength > 0 else {
                previousPoint = currentPoint
                sourceIndex = points.index(after: sourceIndex)
                continue
            }

            if distanceSinceLastSample + segmentLength >= interval {
                let remainingDistance = interval - distanceSinceLastSample
                let interpolationAmount = remainingDistance / segmentLength
                let newPoint = previousPoint.interpolated(
                    toward: currentPoint,
                    amount: interpolationAmount
                )
                sampledPoints.append(newPoint)
                previousPoint = newPoint
                distanceSinceLastSample = 0
            } else {
                distanceSinceLastSample += segmentLength
                previousPoint = currentPoint
                sourceIndex = points.index(after: sourceIndex)
            }
        }

        while sampledPoints.count < count {
            sampledPoints.append(points[points.index(before: points.endIndex)])
        }

        return Array(sampledPoints.prefix(count))
    }
}

private struct NormalizedPoint: Hashable {
    var x: Double
    var y: Double

    static func centroid(of points: [NormalizedPoint]) -> NormalizedPoint {
        guard !points.isEmpty else {
            return NormalizedPoint(x: 0, y: 0)
        }

        let totals = points.reduce(NormalizedPoint(x: 0, y: 0)) { partial, point in
            NormalizedPoint(x: partial.x + point.x, y: partial.y + point.y)
        }

        return NormalizedPoint(
            x: totals.x / Double(points.count),
            y: totals.y / Double(points.count)
        )
    }

    func distance(to other: NormalizedPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension InkPoint {
    func distance(to other: InkPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    func interpolated(toward other: InkPoint, amount: Double) -> InkPoint {
        InkPoint(
            x: x + (other.x - x) * amount,
            y: y + (other.y - y) * amount,
            timeOffset: nil
        )
    }
}
