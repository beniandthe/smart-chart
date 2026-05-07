import XCTest
@testable import SmartChart

final class ChordInkFixtureExporterTests: XCTestCase {
    func testExportsStableFixtureJsonForAcceptedChordInk() throws {
        let strokes = [
            InkStroke(points: [
                InkPoint(x: 40, y: 12, timeOffset: 0.0),
                InkPoint(x: 20, y: 20, timeOffset: 0.1),
                InkPoint(x: 14, y: 42, timeOffset: 0.2),
                InkPoint(x: 36, y: 56, timeOffset: 0.3)
            ]),
            InkStroke(points: [
                InkPoint(x: 52, y: 14, timeOffset: 0.4),
                InkPoint(x: 52, y: 54, timeOffset: 0.5)
            ])
        ]

        let json = try ChordInkFixtureExporter.fixtureJSONString(
            expectedDisplayText: "Bb",
            strokes: strokes
        )
        let decoded = try JSONDecoder().decode(InkFixtureDocument.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.name, "BFlat")
        XCTAssertEqual(decoded.expectedDisplayText, "Bb")
        XCTAssertEqual(decoded.expectedClusterCount, 2)
        XCTAssertEqual(decoded.expectedTopGlyphs, ["B", "b"])
        XCTAssertEqual(decoded.strokes, strokes)
        XCTAssertTrue(json.contains(#""expectedDisplayText" : "Bb""#))
    }

    func testFixtureExportCanonicalizesAcceptedChordAliases() throws {
        let document = try ChordInkFixtureExporter.fixtureDocument(
            expectedDisplayText: "Cmin",
            strokes: [InkStroke(points: [InkPoint(x: 0, y: 0, timeOffset: nil)])]
        )

        XCTAssertEqual(document.expectedDisplayText, "C-")
        XCTAssertEqual(document.expectedTopGlyphs, ["C", "-"])
        XCTAssertEqual(document.name, "CMinor")
    }

    func testFixtureExportNamesUseReadableChordVocabulary() {
        XCTAssertEqual(ChordInkFixtureExporter.fixtureName(for: "F#"), "FSharp")
        XCTAssertEqual(ChordInkFixtureExporter.fixtureName(for: "C△7"), "CMajor7")
        XCTAssertEqual(ChordInkFixtureExporter.fixtureName(for: "G/B"), "GSlashB")
    }

    func testFixtureExportRejectsUnsupportedOrEmptyFixtures() {
        XCTAssertThrowsError(
            try ChordInkFixtureExporter.fixtureDocument(
                expectedDisplayText: "Cmaj7",
                strokes: [InkStroke(points: [InkPoint(x: 0, y: 0, timeOffset: nil)])]
            )
        ) { error in
            XCTAssertEqual(error as? ChordInkFixtureExportError, .unsupportedChord("Cmaj7"))
        }

        XCTAssertThrowsError(
            try ChordInkFixtureExporter.fixtureDocument(
                expectedDisplayText: "C",
                strokes: []
            )
        ) { error in
            XCTAssertEqual(error as? ChordInkFixtureExportError, .emptyInk)
        }
    }
}
