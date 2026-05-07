import XCTest
@testable import SmartChart

final class ChordInkCandidateComposerTests: XCTestCase {
    private let composer = ChordInkCandidateComposer()

    func testComposesBbAheadOfInvalidEightFlatLookalike() {
        let candidates = composer.compose(glyphCandidates: [
            [
                glyph("8", confidence: 0.92),
                glyph("B", confidence: 0.86)
            ],
            [
                glyph("b", confidence: 0.84)
            ]
        ])

        XCTAssertEqual(candidates.first?.text, "Bb")
        XCTAssertEqual(ChordRecognitionCompendium.match(candidates: candidates.map(\.text))?.displayText, "Bb")
    }

    func testComposesSharpAccidentalWithRootWhenNearbyClusterIsPresent() {
        let candidates = composer.compose(glyphCandidates: [
            [glyph("F", confidence: 0.93)],
            [glyph("#", confidence: 0.72)]
        ])

        XCTAssertEqual(candidates.first?.text, "F#")
    }

    func testComposesMinorAliasesToStandardMinorCandidate() throws {
        let dashCandidates = composer.compose(glyphCandidates: [
            [glyph("C", confidence: 0.94)],
            [glyph("-", confidence: 0.86)]
        ])
        let mCandidates = composer.compose(glyphCandidates: [
            [glyph("C", confidence: 0.94)],
            [glyph("m", confidence: 0.86)]
        ])

        XCTAssertEqual(dashCandidates.first?.text, "C-")
        XCTAssertEqual(mCandidates.first?.text, "C-")
        XCTAssertEqual(try ChordSymbolParser.parse(dashCandidates[0].text).displayText, "C-")
        XCTAssertEqual(try ChordSymbolParser.parse(mCandidates[0].text).displayText, "C-")
    }

    func testComposesExtensionAlterationAndSlashBassCandidates() throws {
        let db7b9Candidates = composer.compose(glyphCandidates: [
            [glyph("D", confidence: 0.95)],
            [glyph("b", confidence: 0.85)],
            [glyph("7", confidence: 0.88)],
            [glyph("b", confidence: 0.82)],
            [glyph("9", confidence: 0.88)]
        ])
        let slashCandidates = composer.compose(glyphCandidates: [
            [glyph("G", confidence: 0.94)],
            [glyph("/", confidence: 0.82)],
            [glyph("B", confidence: 0.90)]
        ])

        XCTAssertEqual(db7b9Candidates.first?.text, "Db7b9")
        XCTAssertEqual(try ChordSymbolParser.parse(db7b9Candidates[0].text).displayText, "Db7b9")
        XCTAssertEqual(slashCandidates.first?.text, "G/B")
        XCTAssertEqual(try ChordSymbolParser.parse(slashCandidates[0].text).displayText, "G/B")
    }

    func testComposesTriangleMajorExtensionInsteadOfMajText() throws {
        let candidates = composer.compose(glyphCandidates: [
            [glyph("C", confidence: 0.95)],
            [glyph("△", confidence: 0.83)],
            [glyph("7", confidence: 0.89)]
        ])

        XCTAssertEqual(candidates.first?.text, "C△7")
        XCTAssertEqual(try ChordSymbolParser.parse(candidates[0].text).displayText, "C△7")
        XCTAssertFalse(candidates.map(\.text).contains("Cmaj7"))
    }

    private func glyph(_ text: String, confidence: Double) -> GlyphCandidate {
        GlyphCandidate(text: text, confidence: confidence, source: .template)
    }
}
