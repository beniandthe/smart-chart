#if canImport(UIKit)
import Foundation
import PDFKit
import XCTest
@testable import SmartChart

final class RendererProductProofTests: XCTestCase {
    private struct ProductProofCase {
        var fixtureName: String
        var measureIndex: Int
        var targetFraction: Double
    }

    private let productProofCases = [
        ProductProofCase(fixtureName: "C", measureIndex: 0, targetFraction: 0.05),
        ProductProofCase(fixtureName: "Db7b9", measureIndex: 1, targetFraction: 0.30),
        ProductProofCase(fixtureName: "GSlashB", measureIndex: 2, targetFraction: 0.55)
    ]

    func testBoundedInkProductProofRendersRecognizedChordsInExport() async throws {
        XCTAssertLessThanOrEqual(
            productProofCases.count,
            3,
            "Keep renderer product proof bounded; this is not a personal handwriting training loop."
        )

        let recognizer = ChordInkRecognizer()
        var chart = Chart.blank(
            title: "Renderer Product Proof",
            key: .cMajor,
            measureCount: 4
        )
        var expectedDisplayTexts: [String] = []

        for proofCase in productProofCases {
            let fixture = try InkFixtureLoader.load(proofCase.fixtureName, file: #filePath)
            let result = recognizer.recognize(strokes: fixture.strokes)
            let match = try XCTUnwrap(result.match, fixture.name)
            let measureID = chart.measures[proofCase.measureIndex].id
            let fixtureData = try JSONEncoder().encode(fixture)

            XCTAssertEqual(match.displayText, fixture.expectedDisplayText, fixture.name)
            XCTAssertTrue(chart.setPageHandwrittenChordDrawing(fixtureData), fixture.name)
            XCTAssertTrue(
                chart.appendRecognizedChord(
                    match.symbol,
                    rawInput: fixture.name,
                    to: measureID,
                    atFraction: proofCase.targetFraction,
                    sourceInkData: fixtureData
                ),
                fixture.name
            )
            XCTAssertTrue(chart.setPageHandwrittenChordDrawing(nil), fixture.name)
            XCTAssertNil(chart.pageHandwrittenChordData, fixture.name)

            expectedDisplayTexts.append(fixture.expectedDisplayText)
        }

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exporter = PDFChartExporter(exportDirectory: exportDirectory)

        defer {
            try? FileManager.default.removeItem(at: exportDirectory)
        }

        let exportedURL = try await exporter.exportPDF(for: chart)
        let documentText = try XCTUnwrap(PDFDocument(url: exportedURL)?.string)

        XCTAssertTrue(documentText.contains("Renderer Product Proof"))
        XCTAssertFalse(documentText.contains("Tap the measure in the editor"))
        for expectedDisplayText in expectedDisplayTexts {
            XCTAssertTrue(
                documentText.contains(expectedDisplayText),
                "Expected exported renderer output to contain \(expectedDisplayText). PDF text: \(documentText)"
            )
        }
    }
}
#endif
