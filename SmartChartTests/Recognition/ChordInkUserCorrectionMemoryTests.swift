import XCTest
@testable import SmartChart

final class ChordInkUserCorrectionMemoryTests: XCTestCase {
    func testCompleteFailuresAutoRewriteOnlyTwicePerSlot() {
        let result = ChordInkRecognitionResult(
            rawCandidates: ["scribble"],
            glyphCandidates: [],
            match: nil,
            confidence: 0
        )
        let decision = ChordInkRecognitionDecision(
            action: .confirm,
            acceptedText: nil,
            reason: "No reliable read yet.",
            isCloseRace: false,
            competingCandidateText: nil,
            confidenceGap: nil
        )

        XCTAssertTrue(
            ChordInkUserCorrectionMemoryPolicy.isCompleteFailure(
                result: result,
                decision: decision,
                candidateTexts: []
            )
        )

        var tracker = ChordInkAutomaticRewriteFailureTracker()
        let measureID = UUID()

        XCTAssertEqual(tracker.recordFailure(measureID: measureID, targetFraction: 0.51), 1)
        XCTAssertEqual(tracker.recordFailure(measureID: measureID, targetFraction: 0.51), 2)
        XCTAssertEqual(tracker.recordFailure(measureID: measureID, targetFraction: 0.51), 3)

        tracker.reset()

        XCTAssertEqual(tracker.recordFailure(measureID: measureID, targetFraction: 0.51), 1)
    }

    func testConfirmedSuggestionCreatesRuleForCloseRaceThatIsNotExtremelyClose() {
        var memory = ChordInkUserCorrectionMemory()
        let created = memory.recordConfirmedSuggestion(
            acceptedText: "G/B",
            drawingData: Data("first pass".utf8),
            candidateTexts: ["C", "G/B", "Db7(b9)", "F#"],
            decision: closeRaceDecision(gap: 0.03),
            now: Date(timeIntervalSinceReferenceDate: 10)
        )

        XCTAssertTrue(created)
        XCTAssertEqual(memory.correctionRules.count, 1)
        XCTAssertEqual(memory.correctionRules.first?.candidateSignature, ["C", "G/B", "Db7(b9)"])
        XCTAssertEqual(memory.correctionRules.first?.acceptedText, "G/B")
        XCTAssertEqual(
            memory.preferredCandidate(
                for: ["C", "G/B", "Db7(b9)"],
                decision: closeRaceDecision(gap: 0.03)
            ),
            "G/B"
        )
    }

    func testConfirmedSuggestionDoesNotCreateRuleForExtremelyTightRace() {
        var memory = ChordInkUserCorrectionMemory()
        let created = memory.recordConfirmedSuggestion(
            acceptedText: "Db7(b9)",
            drawingData: Data("very tight".utf8),
            candidateTexts: ["Db7/Gb", "Db7(b9)", "Db7"],
            decision: closeRaceDecision(gap: 0.01)
        )

        XCTAssertFalse(created)
        XCTAssertTrue(memory.correctionRules.isEmpty)
        XCTAssertNil(
            memory.preferredCandidate(
                for: ["Db7/Gb", "Db7(b9)", "Db7"],
                decision: closeRaceDecision(gap: 0.01)
            )
        )
    }

    func testManualCorrectionCreatesExclusionAndRemovesMatchingRule() {
        var memory = ChordInkUserCorrectionMemory()
        XCTAssertTrue(
            memory.recordConfirmedSuggestion(
                acceptedText: "C",
                drawingData: Data("rule".utf8),
                candidateTexts: ["C", "G/B", "Db7(b9)"],
                decision: closeRaceDecision(gap: 0.03)
            )
        )

        let excluded = memory.recordManualCorrection(
            acceptedText: "F#",
            drawingData: Data("manual".utf8),
            candidateTexts: ["C", "G/B", "Db7(b9)"],
            now: Date(timeIntervalSinceReferenceDate: 20)
        )

        XCTAssertTrue(excluded)
        XCTAssertTrue(memory.correctionRules.isEmpty)
        XCTAssertEqual(memory.suggestionExclusions.count, 1)
        XCTAssertEqual(memory.suggestionExclusions.first?.rejectedCandidateTexts, ["C", "G/B", "Db7(b9)"])
        XCTAssertEqual(memory.suggestionExclusions.first?.acceptedText, "F#")
        XCTAssertNil(
            memory.preferredCandidate(
                for: ["C", "G/B", "Db7(b9)"],
                decision: closeRaceDecision(gap: 0.03)
            )
        )
    }

    func testStorePersistsUserCorrectionMemoryWhenPathContainsSpaces() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let store = ChordInkUserCorrectionMemoryStore(
            url: temporaryDirectory.appendingPathComponent("chord-ink-user-correction-memory.json")
        )
        var memory = ChordInkUserCorrectionMemory()
        XCTAssertTrue(
            memory.recordConfirmedSuggestion(
                acceptedText: "G/B",
                drawingData: Data("stored".utf8),
                candidateTexts: ["C", "G/B", "Db7(b9)"],
                decision: closeRaceDecision(gap: 0.03),
                now: Date(timeIntervalSinceReferenceDate: 30)
            )
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory.deletingLastPathComponent())
        }

        try store.save(memory)

        XCTAssertEqual(try store.load(), memory)
    }

    private func closeRaceDecision(gap: Double) -> ChordInkRecognitionDecision {
        ChordInkRecognitionDecision(
            action: .confirm,
            acceptedText: "G/B",
            reason: "Close race. Choose the chord you meant, or type it in.",
            isCloseRace: true,
            competingCandidateText: "C",
            confidenceGap: gap
        )
    }
}
