import CoreGraphics
import Foundation
import OSLog

enum ChordRecognitionTelemetryOutcome: String, Codable, Hashable {
    case recognized
    case confirmationOffered
    case unrecognized
    case appendFailed
}

struct ChordRecognitionTelemetryRecord: Codable, Hashable, Identifiable {
    var id: UUID
    var schemaVersion: Int?
    var recognitionSessionID: UUID?
    var timestamp: Date
    var chartID: UUID
    var measureID: UUID
    var insertionFraction: Double
    var outcome: ChordRecognitionTelemetryOutcome
    var textCandidates: [String]
    var methodCandidates: [ChordRecognitionTelemetryCandidate]
    var rawMethodCandidates: [ChordRecognitionTelemetryCandidate]?
    var bestDisplayText: String?
    var bestMethod: String?
    var bestConfidence: Double?
    var reportSummary: String
    var resolvedReportSummary: String?
    var inkMetrics: ChordRecognitionInkMetrics?
    var confirmedExampleCount: Int?
    var recognitionDurationMillis: Double?
    var wouldAutoAccept: Bool?
    var requiresConfirmation: Bool?
    var confidenceMargin: Double?
    var intentSummary: String?
    var intentWarnings: [String]?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        chartID: UUID,
        measureID: UUID,
        insertionFraction: Double,
        outcome: ChordRecognitionTelemetryOutcome,
        textCandidates: [String],
        report: ChordRecognitionReport,
        inkSample: ChordRecognitionInkSample?,
        confirmedExampleCount: Int? = nil,
        recognitionDurationMillis: Double? = nil,
        requiresConfirmation: Bool? = nil
    ) {
        let resolvedCandidates = report.strongestCandidatesBySymbol
        let rawCandidates = report.candidates
            .sorted { $0.confidence > $1.confidence }
        let bestCandidate = resolvedCandidates.first
        self.id = id
        self.schemaVersion = 3
        self.recognitionSessionID = ChordRecognitionTelemetryStore.currentSessionID
        self.timestamp = timestamp
        self.chartID = chartID
        self.measureID = measureID
        self.insertionFraction = insertionFraction
        self.outcome = outcome
        self.textCandidates = textCandidates
        self.methodCandidates = resolvedCandidates
            .map(ChordRecognitionTelemetryCandidate.init(candidate:))
        self.rawMethodCandidates = rawCandidates
            .map(ChordRecognitionTelemetryCandidate.init(candidate:))
        self.bestDisplayText = bestCandidate?.match.displayText
        self.bestMethod = bestCandidate?.method.rawValue
        self.bestConfidence = bestCandidate?.confidence
        self.reportSummary = report.debugSummary
        self.resolvedReportSummary = Self.summary(for: resolvedCandidates)
        self.inkMetrics = inkSample.map(ChordRecognitionInkMetrics.init(sample:))
        self.confirmedExampleCount = confirmedExampleCount
        self.recognitionDurationMillis = recognitionDurationMillis
        self.wouldAutoAccept = report.shouldAutoAcceptBestCandidate
        self.requiresConfirmation = requiresConfirmation
        self.confidenceMargin = report.bestConfidenceMargin
        self.intentSummary = ChordRecognitionIntentAudit.summary(for: report)
        self.intentWarnings = ChordRecognitionIntentAudit.warnings(for: report)
    }

    private static func summary(
        for candidates: [ChordRecognitionCandidate]
    ) -> String {
        guard !candidates.isEmpty else {
            return "no candidates"
        }

        return candidates
            .map { candidate in
                "\(candidate.method.rawValue):\(candidate.match.displayText)@\(String(format: "%.2f", candidate.confidence))"
            }
            .joined(separator: " | ")
    }
}

struct ChordRecognitionTelemetryCandidate: Codable, Hashable {
    var method: String
    var displayText: String
    var confidence: Double
    var debugSummary: String

    init(candidate: ChordRecognitionCandidate) {
        method = candidate.method.rawValue
        displayText = candidate.match.displayText
        confidence = candidate.confidence
        debugSummary = candidate.debugSummary
    }
}

struct ChordRecognitionInkMetrics: Codable, Hashable {
    var strokeCount: Int
    var pointCount: Int
    var bounds: ChordRecognitionTelemetryRect?
    var sampledNormalizedStrokes: [[ChordRecognitionTelemetryPoint]]

    init(sample: ChordRecognitionInkSample) {
        strokeCount = sample.strokes.count
        pointCount = sample.allPoints.count
        bounds = sample.bounds.map(ChordRecognitionTelemetryRect.init(rect:))
        sampledNormalizedStrokes = sample.sampledNormalizedStrokes().map { stroke in
            stroke.map(ChordRecognitionTelemetryPoint.init(point:))
        }
    }
}

struct ChordRecognitionTelemetryPoint: Codable, Hashable {
    var x: Double
    var y: Double

    init(point: CGPoint) {
        x = Double(point.x)
        y = Double(point.y)
    }
}

struct ChordRecognitionTelemetryRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(rect: CGRect) {
        x = Double(rect.minX)
        y = Double(rect.minY)
        width = Double(rect.width)
        height = Double(rect.height)
    }
}

enum ChordRecognitionTelemetryStore {
    static let currentSessionID = UUID()
    private static let logger = Logger(
        subsystem: "com.smartchart.app",
        category: "ChordRecognition"
    )
    private static let queue = DispatchQueue(
        label: "com.smartchart.chord-recognition-telemetry",
        qos: .utility
    )

    static var defaultURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("SmartChart", isDirectory: true)
            .appendingPathComponent("Debug", isDirectory: true)
            .appendingPathComponent("chord-recognition-telemetry.jsonl")
    }

    static func record(_ record: ChordRecognitionTelemetryRecord) {
        logger.info(
            "Chord recognition outcome=\(record.outcome.rawValue, privacy: .public) best=\(record.bestDisplayText ?? "none", privacy: .public) method=\(record.bestMethod ?? "none", privacy: .public) requiresConfirmation=\(record.requiresConfirmation ?? false, privacy: .public) wouldAutoAccept=\(record.wouldAutoAccept ?? false, privacy: .public) durationMs=\(record.recognitionDurationMillis ?? -1, privacy: .public) examples=\(record.confirmedExampleCount ?? -1, privacy: .public) intent=\(record.intentSummary ?? "none", privacy: .public) resolved=\(record.resolvedReportSummary ?? "none", privacy: .public) raw=\(record.reportSummary, privacy: .public)"
        )

        queue.async {
            do {
                try append(record, to: defaultURL)
            } catch {
                logger.error("Failed to persist chord recognition telemetry: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func append(
        _ record: ChordRecognitionTelemetryRecord,
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedRecord = try encoder.encode(record)
        var lineData = encodedRecord
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
    ) throws -> [ChordRecognitionTelemetryRecord] {
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
                    ChordRecognitionTelemetryRecord.self,
                    from: Data(line.utf8)
                )
            }
    }
}
