import CoreGraphics
import Foundation
import OSLog

struct ChordRecognitionLearningExample: Codable, Hashable, Identifiable {
    var id: UUID
    var createdAt: Date
    var displayText: String
    var rawInput: String
    var ink: ChordRecognitionLearningInk
    var sourceMethod: String?
    var sourceConfidence: Double?
    var sourceReportSummary: String?
    var suggestedDisplayText: String?
    var suggestedMethod: String?
    var suggestedConfidence: Double?
    var wasCorrection: Bool?
    var correctionWeight: Double?
    var sourceTelemetryID: UUID?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        match: ChordRecognitionMatch,
        ink: ChordRecognitionLearningInk,
        sourceMethod: String? = nil,
        sourceConfidence: Double? = nil,
        sourceReportSummary: String? = nil,
        suggestedDisplayText: String? = nil,
        suggestedMethod: String? = nil,
        suggestedConfidence: Double? = nil,
        wasCorrection: Bool? = nil,
        correctionWeight: Double? = nil,
        sourceTelemetryID: UUID? = nil
    ) {
        let resolvedWasCorrection = wasCorrection ?? suggestedDisplayText.map { $0 != match.displayText } ?? false
        self.id = id
        self.createdAt = createdAt
        displayText = match.displayText
        rawInput = match.rawInput
        self.ink = ink
        self.sourceMethod = sourceMethod
        self.sourceConfidence = sourceConfidence
        self.sourceReportSummary = sourceReportSummary
        self.suggestedDisplayText = suggestedDisplayText
        self.suggestedMethod = suggestedMethod
        self.suggestedConfidence = suggestedConfidence
        self.wasCorrection = resolvedWasCorrection
        self.correctionWeight = correctionWeight ?? (resolvedWasCorrection ? 2.5 : 1)
        self.sourceTelemetryID = sourceTelemetryID
    }

    var effectiveWeight: Double {
        min(3, max(0.25, correctionWeight ?? 1))
    }
}

struct ChordRecognitionLearningInk: Codable, Hashable {
    var strokeCount: Int
    var pointCount: Int
    var aspectRatio: Double
    var sampledNormalizedStrokes: [[ChordRecognitionLearningPoint]]

    init(sample: ChordRecognitionInkSample) {
        strokeCount = sample.strokes.count
        pointCount = sample.allPoints.count
        if let bounds = sample.bounds,
           bounds.height > 0 {
            aspectRatio = Double(bounds.width / bounds.height)
        } else {
            aspectRatio = 1
        }
        sampledNormalizedStrokes = sample.sampledNormalizedStrokes().map { stroke in
            stroke.map(ChordRecognitionLearningPoint.init(point:))
        }
    }

    var inkSample: ChordRecognitionInkSample {
        ChordRecognitionInkSample(
            strokes: sampledNormalizedStrokes.map { stroke in
                stroke.map { point in
                    CGPoint(x: point.x * 100, y: point.y * 100)
                }
            }
        )
    }

    func similarity(to other: ChordRecognitionLearningInk) -> Double {
        let gridSimilarity = jaccardSimilarity(
            occupiedCells(gridSize: 12),
            other.occupiedCells(gridSize: 12)
        )
        let regionSimilarity = histogramCosineSimilarity(
            regionHistogram(columns: 4, rows: 4),
            other.regionHistogram(columns: 4, rows: 4)
        )
        let aspectSimilarity = max(0, 1 - abs(aspectRatio - other.aspectRatio) / 0.95)
        let strokeSimilarity = max(0, 1 - Double(abs(strokeCount - other.strokeCount)) / 5)
        let pointSimilarity = max(0, 1 - abs(Double(pointCount - other.pointCount)) / Double(max(pointCount, other.pointCount, 1)))

        return min(
            1,
            max(
                0,
                gridSimilarity * 0.46
                    + regionSimilarity * 0.28
                    + aspectSimilarity * 0.12
                    + strokeSimilarity * 0.08
                    + pointSimilarity * 0.06
            )
        )
    }

    private var points: [ChordRecognitionLearningPoint] {
        sampledNormalizedStrokes.flatMap { $0 }
    }

    private func occupiedCells(gridSize: Int) -> Set<Int> {
        var cells = Set<Int>()

        for stroke in sampledNormalizedStrokes {
            guard let firstPoint = stroke.first else {
                continue
            }

            cells.insert(cell(for: firstPoint, gridSize: gridSize))
            for segment in zip(stroke, stroke.dropFirst()) {
                let dx = segment.1.x - segment.0.x
                let dy = segment.1.y - segment.0.y
                let segmentLength = hypot(dx, dy)
                let steps = max(1, Int(ceil(segmentLength * Double(gridSize) * 2)))
                for step in 0...steps {
                    let t = Double(step) / Double(steps)
                    let point = ChordRecognitionLearningPoint(
                        x: segment.0.x + dx * t,
                        y: segment.0.y + dy * t
                    )
                    cells.insert(cell(for: point, gridSize: gridSize))
                }
            }
        }

        return cells
    }

    private func regionHistogram(columns: Int, rows: Int) -> [Double] {
        var histogram = Array(repeating: 0.0, count: columns * rows)
        for point in points {
            let column = min(columns - 1, max(0, Int((point.x * Double(columns)).rounded(.down))))
            let row = min(rows - 1, max(0, Int((point.y * Double(rows)).rounded(.down))))
            histogram[row * columns + column] += 1
        }

        let total = histogram.reduce(0, +)
        guard total > 0 else {
            return histogram
        }

        return histogram.map { $0 / total }
    }

    private func cell(for point: ChordRecognitionLearningPoint, gridSize: Int) -> Int {
        let x = min(gridSize - 1, max(0, Int((point.x * Double(gridSize)).rounded(.down))))
        let y = min(gridSize - 1, max(0, Int((point.y * Double(gridSize)).rounded(.down))))
        return y * gridSize + x
    }

    private func jaccardSimilarity(_ lhs: Set<Int>, _ rhs: Set<Int>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else {
            return 0
        }

        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        return Double(intersection) / Double(max(union, 1))
    }

    private func histogramCosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count else {
            return 0
        }

        let dotProduct = zip(lhs, rhs).reduce(0.0) { partialResult, pair in
            partialResult + pair.0 * pair.1
        }
        let lhsMagnitude = sqrt(lhs.reduce(0.0) { $0 + $1 * $1 })
        let rhsMagnitude = sqrt(rhs.reduce(0.0) { $0 + $1 * $1 })
        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            return 0
        }

        return dotProduct / (lhsMagnitude * rhsMagnitude)
    }
}

struct ChordRecognitionLearningPoint: Codable, Hashable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(point: CGPoint) {
        x = Double(point.x)
        y = Double(point.y)
    }
}

enum ChordRecognitionLearningStore {
    private static let logger = Logger(
        subsystem: "com.smartchart.app",
        category: "ChordRecognitionLearning"
    )
    private static let queue = DispatchQueue(
        label: "com.smartchart.chord-recognition-learning",
        qos: .utility
    )
    private static var cachedExamples: [ChordRecognitionLearningExample]?
    private static let activeUserConfirmationLimitPerSymbol = 3
    private static let activeUserCorrectionLimitPerSymbol = 3
    private static let activeNaturalSeedBaselinePerSymbol = 4

    static var defaultURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("SmartChart", isDirectory: true)
            .appendingPathComponent("Learning", isDirectory: true)
            .appendingPathComponent("chord-recognition-confirmed-examples.jsonl")
    }

    static func examples(
        from url: URL = defaultURL,
        fileManager: FileManager = .default
    ) -> [ChordRecognitionLearningExample] {
        queue.sync {
            if url == defaultURL,
               let cachedExamples {
                return cachedExamples
            }

            let userExamples = (try? records(from: url, fileManager: fileManager)) ?? []
            let activeExamples = activeExamples(
                userExamples: userExamples,
                seedExamples: bundledSeedExamples(fileManager: fileManager)
            )
            if url == defaultURL {
                cachedExamples = activeExamples
                logger.info(
                    "Active chord learning examples=\(activeExamples.count, privacy: .public)"
                )
            }
            return activeExamples
        }
    }

    static func recordConfirmedExample(_ example: ChordRecognitionLearningExample) {
        logger.info(
            "Confirmed chord learning example symbol=\(example.displayText, privacy: .public) method=\(example.sourceMethod ?? "none", privacy: .public)"
        )

        queue.async {
            do {
                try append(example, to: defaultURL)
                cachedExamples = activeExamples(
                    userExamples: try records(from: defaultURL),
                    seedExamples: bundledSeedExamples()
                )
            } catch {
                logger.error("Failed to persist confirmed chord example: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func append(
        _ example: ChordRecognitionLearningExample,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedExample = try encoder.encode(example)
        var lineData = encodedExample
        lineData.append(Data("\n".utf8))

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: lineData)
    }

    static func records(
        from url: URL = defaultURL,
        fileManager: FileManager = .default
    ) throws -> [ChordRecognitionLearningExample] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        guard let contents = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try contents
            .split(separator: "\n")
            .map { line in
                try decoder.decode(
                    ChordRecognitionLearningExample.self,
                    from: Data(line.utf8)
                )
            }
    }

    static func bundledSeedExamples(
        fileManager: FileManager = .default
    ) -> [ChordRecognitionLearningExample] {
        guard let url = Bundle.main.url(
            forResource: "chord-recognition-base-seed",
            withExtension: "jsonl"
        ) else {
            return []
        }

        return (try? records(from: url, fileManager: fileManager)) ?? []
    }

    static func activeExamples(
        userExamples: [ChordRecognitionLearningExample],
        seedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionLearningExample] {
        let uniqueUserExamples = deduplicatedExamples(userExamples)
        let activeUserExamples = uniqueUserExamples
            .groupedByDisplayText()
            .flatMap { _, examples in
                curatedExamples(
                    examples,
                    confirmationLimit: activeUserConfirmationLimitPerSymbol,
                    correctionLimit: activeUserCorrectionLimitPerSymbol
                )
            }

        let rawUserCountsBySymbol = Dictionary(
            grouping: uniqueUserExamples,
            by: \.displayText
        ).mapValues(\.count)
        let activeSeedExamples = deduplicatedExamples(seedExamples)
            .filter(isNaturalMajorSeedExample)
            .groupedByDisplayText()
            .flatMap { symbol, examples -> [ChordRecognitionLearningExample] in
                let remainingSeedSlots = max(
                    0,
                    activeNaturalSeedBaselinePerSymbol - rawUserCountsBySymbol[symbol, default: 0]
                )
                guard remainingSeedSlots > 0 else {
                    return []
                }

                return curatedExamples(
                    examples,
                    confirmationLimit: remainingSeedSlots,
                    correctionLimit: 0
                )
            }

        return deduplicatedExamples(activeUserExamples + activeSeedExamples)
            .sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
    }

    private static func curatedExamples(
        _ examples: [ChordRecognitionLearningExample],
        confirmationLimit: Int,
        correctionLimit: Int
    ) -> [ChordRecognitionLearningExample] {
        let recentExamples = examples.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
        let corrections = recentExamples
            .filter { $0.wasCorrection == true }
            .prefix(correctionLimit)
        let confirmations = recentExamples
            .filter { $0.wasCorrection != true }
            .prefix(confirmationLimit)

        return Array(corrections + confirmations)
    }

    private static func deduplicatedExamples(
        _ examples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionLearningExample] {
        var seenIDs = Set<UUID>()
        return examples.filter { example in
            seenIDs.insert(example.id).inserted
        }
    }

    private static func isNaturalMajorSeedExample(
        _ example: ChordRecognitionLearningExample
    ) -> Bool {
        guard let match = ChordRecognitionCompendium.match(example.displayText) else {
            return false
        }

        return match.symbol.accidental == .natural
            && match.symbol.quality.isEmpty
            && example.wasCorrection != true
    }
}

private extension Array where Element == ChordRecognitionLearningExample {
    func groupedByDisplayText() -> [String: [ChordRecognitionLearningExample]] {
        Dictionary(grouping: self, by: \.displayText)
    }
}
