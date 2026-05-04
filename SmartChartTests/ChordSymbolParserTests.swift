import XCTest
@testable import SmartChart

final class ChordSymbolParserTests: XCTestCase {
    func testChordRecognitionCompendiumMatchesCompatibilityWrapper() {
        for spelling in ["C", "Db", "F#", "Bb-"] {
            XCTAssertEqual(
                ChordRecognitionCompendium.match(spelling)?.displayText,
                BasicMajorChordCompendium.match(spelling)?.displayText
            )
        }
    }

    func testBasicMajorChordCompendiumRecognizesChromaticSpellings() throws {
        let expectedSpellings = [
            "C",
            "C#",
            "Cb",
            "D",
            "D#",
            "Db",
            "E",
            "E#",
            "Eb",
            "F",
            "F#",
            "Fb",
            "G",
            "G#",
            "Gb",
            "A",
            "A#",
            "Ab",
            "B",
            "B#",
            "Bb"
        ]

        for spelling in expectedSpellings {
            let match = try XCTUnwrap(
                BasicMajorChordCompendium.match(spelling),
                "Expected compendium to recognize \(spelling)"
            )
            XCTAssertEqual(match.displayText, spelling)
            XCTAssertTrue(match.symbol.quality.isEmpty)
        }
    }

    func testBasicMajorChordCompendiumNormalizesHandwritingOcrVariants() {
        XCTAssertEqual(BasicMajorChordCompendium.match(" d flat ")?.displayText, "Db")
        XCTAssertEqual(BasicMajorChordCompendium.match("F sharp")?.displayText, "F#")
        XCTAssertEqual(BasicMajorChordCompendium.match("B♭")?.displayText, "Bb")
        XCTAssertNil(BasicMajorChordCompendium.match("Cm7"))
    }

    func testBasicMajorChordCompendiumRecognizesMinorAliases() {
        XCTAssertEqual(BasicMajorChordCompendium.match("C-")?.displayText, "C-")
        XCTAssertEqual(BasicMajorChordCompendium.match("Cm")?.displayText, "C-")
        XCTAssertEqual(BasicMajorChordCompendium.match("Cmin")?.displayText, "C-")
        XCTAssertEqual(BasicMajorChordCompendium.match("C minor")?.displayText, "C-")
        XCTAssertEqual(BasicMajorChordCompendium.match("B♭min")?.displayText, "Bb-")
        XCTAssertEqual(BasicMajorChordCompendium.match("F sharp m")?.displayText, "F#-")
    }

    func testBasicMajorChordCompendiumRejectsMajorSuffixAliases() {
        XCTAssertNil(BasicMajorChordCompendium.match("CM"))
        XCTAssertNil(BasicMajorChordCompendium.match("Cmaj"))
        XCTAssertNil(BasicMajorChordCompendium.match("C major"))
        XCTAssertNil(BasicMajorChordCompendium.match("C#M"))
        XCTAssertNil(BasicMajorChordCompendium.match("Bbmaj"))
    }

    func testZeroTranspositionPreservesWrittenEnharmonicSpellings() throws {
        let spellings = ["Cb", "E#", "Fb", "B#"]

        for spelling in spellings {
            let symbol = try XCTUnwrap(BasicMajorChordCompendium.match(spelling)?.symbol)

            XCTAssertEqual(symbol.transposed(by: 0).displayText, spelling)
        }
    }

    func testConcertChordEventViewPreservesWrittenEnharmonicSpellings() throws {
        let symbol = try XCTUnwrap(BasicMajorChordCompendium.match("E#")?.symbol)
        let event = ChordEvent(
            id: UUID(),
            symbol: symbol,
            startPosition: BeatPosition(beat: 1, subdivision: 0, subdivisionsPerBeat: 1),
            duration: .quarter,
            rhythmPlacement: .inline,
            tieOut: false,
            hitStyle: .none,
            rawInput: "E#"
        )

        XCTAssertEqual(event.transposed(for: TranspositionView.concert).symbol.displayText, "E#")
    }

    func testParsesChordWithExtensionAlterationAndSlashBass() throws {
        let symbol = try ChordSymbolParser.parse("Bb7b9/D")

        XCTAssertEqual(symbol.root, .b)
        XCTAssertEqual(symbol.accidental, .flat)
        XCTAssertEqual(symbol.quality, "")
        XCTAssertEqual(symbol.extensions, ["7"])
        XCTAssertEqual(symbol.alterations, ["b9"])
        XCTAssertEqual(symbol.slashBass, "D")
    }

    func testParsesMinorChordAliasesToJazzMinorQuality() throws {
        for spelling in ["C-", "Cm", "Cmin", "Cminor", "C minor"] {
            let symbol = try ChordSymbolParser.parse(spelling)

            XCTAssertEqual(symbol.displayText, "C-", spelling)
        }

        let extendedMinor = try ChordSymbolParser.parse("Dbmin7")

        XCTAssertEqual(extendedMinor.displayText, "Db-7")
    }

    func testParserRejectsUnsupportedMajorSuffixAliases() {
        for spelling in ["CM", "Cmaj", "Cmajor", "C major", "Bbmaj7"] {
            XCTAssertThrowsError(try ChordSymbolParser.parse(spelling), spelling)
        }
    }

    func testParsesMeterWithWhitespace() throws {
        let meter = try MeterParser.parse(" 6/8 ")

        XCTAssertEqual(meter.numerator, 6)
        XCTAssertEqual(meter.denominator, 8)
    }
}
