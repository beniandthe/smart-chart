import Foundation

struct InkPoint: Codable, Hashable {
    var x: Double
    var y: Double
    var timeOffset: TimeInterval?
}

struct InkBounds: Codable, Hashable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double {
        max(0, maxX - minX)
    }

    var height: Double {
        max(0, maxY - minY)
    }

    static let zero = InkBounds(minX: 0, minY: 0, maxX: 0, maxY: 0)

    static func enclosing(_ points: [InkPoint]) -> InkBounds {
        guard let firstPoint = points.first else {
            return .zero
        }

        return points.dropFirst().reduce(
            InkBounds(
                minX: firstPoint.x,
                minY: firstPoint.y,
                maxX: firstPoint.x,
                maxY: firstPoint.y
            )
        ) { bounds, point in
            bounds.union(
                InkBounds(
                    minX: point.x,
                    minY: point.y,
                    maxX: point.x,
                    maxY: point.y
                )
            )
        }
    }

    static func enclosing(_ bounds: [InkBounds]) -> InkBounds {
        guard let firstBounds = bounds.first else {
            return .zero
        }

        return bounds.dropFirst().reduce(firstBounds) { partialBounds, nextBounds in
            partialBounds.union(nextBounds)
        }
    }

    func union(_ other: InkBounds) -> InkBounds {
        InkBounds(
            minX: min(minX, other.minX),
            minY: min(minY, other.minY),
            maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY)
        )
    }
}

struct InkStroke: Codable, Hashable {
    var points: [InkPoint]
    var bounds: InkBounds

    init(points: [InkPoint], bounds: InkBounds? = nil) {
        self.points = points
        self.bounds = bounds ?? InkBounds.enclosing(points)
    }
}

struct InkCluster: Codable, Hashable {
    var strokes: [InkStroke]
    var bounds: InkBounds
    var startTimeOffset: TimeInterval?
    var endTimeOffset: TimeInterval?

    init(
        strokes: [InkStroke],
        bounds: InkBounds? = nil,
        startTimeOffset: TimeInterval? = nil,
        endTimeOffset: TimeInterval? = nil
    ) {
        self.strokes = strokes
        self.bounds = bounds ?? InkBounds.enclosing(strokes.map(\.bounds))
        self.startTimeOffset = startTimeOffset ?? strokes
            .flatMap(\.points)
            .compactMap(\.timeOffset)
            .min()
        self.endTimeOffset = endTimeOffset ?? strokes
            .flatMap(\.points)
            .compactMap(\.timeOffset)
            .max()
    }
}

enum RecognitionSource: String, Codable, Hashable {
    case template
    case heuristic
    case composer
}

struct GlyphCandidate: Hashable {
    var text: String
    var confidence: Double
    var source: RecognitionSource
}

struct ChordInkRecognitionResult: Hashable {
    var rawCandidates: [String]
    var glyphCandidates: [[GlyphCandidate]]
    var match: ChordRecognitionMatch?
    var confidence: Double
}

struct InkFixtureDocument: Codable, Hashable {
    var name: String
    var expectedDisplayText: String
    var expectedClusterCount: Int?
    var expectedTopGlyphs: [String]
    var strokes: [InkStroke]

    init(
        name: String,
        expectedDisplayText: String,
        expectedClusterCount: Int? = nil,
        expectedTopGlyphs: [String] = [],
        strokes: [InkStroke]
    ) {
        self.name = name
        self.expectedDisplayText = expectedDisplayText
        self.expectedClusterCount = expectedClusterCount
        self.expectedTopGlyphs = expectedTopGlyphs
        self.strokes = strokes
    }
}
