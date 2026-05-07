import XCTest
@testable import SmartChart

final class ChordInkRecognizerTests: XCTestCase {
    private let recognizer = ChordInkRecognizer()

    func testRecognizesEveryInkFixtureThroughPureSwiftPipeline() throws {
        for fixture in try InkFixtureLoader.loadAll(file: #filePath) {
            let result = recognizer.recognize(strokes: fixture.strokes)

            XCTAssertEqual(result.match?.displayText, fixture.expectedDisplayText, fixture.name)
            XCTAssertFalse(result.rawCandidates.isEmpty, fixture.name)
            XCTAssertEqual(result.glyphCandidates.count, fixture.expectedClusterCount, fixture.name)
            XCTAssertGreaterThan(result.confidence, 0, fixture.name)
        }
    }

    func testSuccessCriteriaFixturesArePresent() throws {
        let fixtures = try InkFixtureLoader.loadAll(file: #filePath)
        let displayTexts = Set(fixtures.map(\.expectedDisplayText))

        XCTAssertTrue(displayTexts.isSuperset(of: ["C", "Bb", "F#", "C-", "C-7", "Db7b9", "G/B"]))
    }

    func testRecognizerReturnsDebugDataWhenInkCannotMatchAChord() {
        let result = recognizer.recognize(strokes: [
            InkStroke(points: [
                InkPoint(x: 10, y: 10, timeOffset: 0),
                InkPoint(x: 18, y: 18, timeOffset: 0.1)
            ])
        ])

        XCTAssertNil(result.match)
        XCTAssertFalse(result.glyphCandidates.isEmpty)
        XCTAssertFalse(result.rawCandidates.isEmpty)
        XCTAssertEqual(result.confidence, 0)
    }
}
