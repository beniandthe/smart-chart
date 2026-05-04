import Foundation

struct ChordRecognitionProposal: Identifiable, Equatable {
    let id = UUID()
    var telemetryID: UUID
    var measureID: UUID
    var measureIndex: Int
    var symbol: ChordSymbol
    var rawInput: String
    var insertionFraction: Double
    var confidence: Double
    var methodName: String
    var reportSummary: String
    var learningInk: ChordRecognitionLearningInk?
    var remainingChordDrawingData: Data?

    var displayMeasureNumber: Int {
        measureIndex + 1
    }
}
