import XCTest
@testable import SmartChart

final class GestureTemplateRecognizerTests: XCTestCase {
    private let clusterer = StrokeClusterer()
    private let recognizer = GestureTemplateRecognizer()

    func testExpectedGlyphAppearsInTopThreeForCurrentFixtures() throws {
        let templates = ChordGlyphTemplateLibrary.initialTemplates

        for fixture in try InkFixtureLoader.loadAll(file: #filePath) {
            let clusters = clusterer.cluster(fixture.strokes)

            XCTAssertEqual(clusters.count, fixture.expectedTopGlyphs.count, fixture.name)

            for (cluster, expectedGlyph) in zip(clusters, fixture.expectedTopGlyphs) {
                let topThree = recognizer
                    .rankedCandidates(for: cluster, templates: templates, limit: 3)
                    .map(\.text)

                XCTAssertTrue(
                    topThree.contains(expectedGlyph),
                    "Expected \(expectedGlyph) in top 3 for \(fixture.name), got \(topThree)"
                )
            }
        }
    }

    func testConfidenceSortsNearestTemplateFirst() throws {
        let templates = ChordGlyphTemplateLibrary.initialTemplates
        let fixture = try InkFixtureLoader.load("C", file: #filePath)
        let cluster = try XCTUnwrap(clusterer.cluster(fixture.strokes).first)

        let candidates = recognizer.rankedCandidates(for: cluster, templates: templates, limit: 4)

        XCTAssertEqual(candidates.first?.text, "C")
        XCTAssertEqual(candidates.map(\.confidence), candidates.map(\.confidence).sorted(by: >))
        XCTAssertEqual(Set(candidates.map(\.source)), [.template])
    }

    func testRecognitionIsStableAcrossScaleAndTranslation() throws {
        let templates = ChordGlyphTemplateLibrary.initialTemplates
        let fixture = try InkFixtureLoader.load("C", file: #filePath)
        let scaledAndTranslatedStrokes = fixture.strokes.map { stroke in
            stroke.transformed(scale: 1.7, translateX: 120, translateY: -42)
        }
        let cluster = try XCTUnwrap(clusterer.cluster(scaledAndTranslatedStrokes).first)

        let candidates = recognizer.rankedCandidates(for: cluster, templates: templates, limit: 3)

        XCTAssertEqual(candidates.first?.text, "C")
    }

    func testRecognizerReturnsAmbiguousCandidatesInsteadOfForcingOneAnswer() throws {
        let fixture = try InkFixtureLoader.load("C", file: #filePath)
        let cluster = try XCTUnwrap(clusterer.cluster(fixture.strokes).first)
        let templates = [
            GestureTemplate(text: "C", strokes: cluster.strokes),
            GestureTemplate(text: "open-C", strokes: cluster.strokes)
        ]

        let candidates = recognizer.rankedCandidates(for: cluster, templates: templates)

        XCTAssertEqual(candidates.map(\.text), ["C", "open-C"])
        XCTAssertEqual(candidates[0].confidence, candidates[1].confidence, accuracy: 0.0001)
    }

    func testRecognizerCollapsesDuplicateTemplateTextsToBestCandidate() throws {
        let fixture = try InkFixtureLoader.load("C", file: #filePath)
        let cluster = try XCTUnwrap(clusterer.cluster(fixture.strokes).first)
        let templates = [
            GestureTemplate(text: "C", strokes: cluster.strokes),
            GestureTemplate(text: "C", strokes: [InkStroke(points: [
                InkPoint(x: 0, y: 0, timeOffset: nil),
                InkPoint(x: 10, y: 10, timeOffset: nil)
            ])])
        ]

        let candidates = recognizer.rankedCandidates(for: cluster, templates: templates)

        XCTAssertEqual(candidates.map(\.text), ["C"])
    }
}

private extension InkStroke {
    func transformed(scale: Double, translateX: Double, translateY: Double) -> InkStroke {
        InkStroke(
            points: points.map { point in
                InkPoint(
                    x: point.x * scale + translateX,
                    y: point.y * scale + translateY,
                    timeOffset: point.timeOffset
                )
            }
        )
    }
}
