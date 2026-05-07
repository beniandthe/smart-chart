import XCTest
@testable import SmartChart

final class ChordSymbolParserTests: XCTestCase {
    private let chromaticSpellings = [
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

    func testChordRecognitionCompendiumMatchesCompatibilityWrapper() {
        for spelling in chromaticSpellings + chromaticSpellings.map({ "\($0)-" }) {
            XCTAssertEqual(
                ChordRecognitionCompendium.match(spelling)?.displayText,
                BasicMajorChordCompendium.match(spelling)?.displayText
            )
        }
    }

    func testBasicMajorChordCompendiumRecognizesChromaticSpellings() throws {
        for spelling in chromaticSpellings {
            let match = try XCTUnwrap(
                BasicMajorChordCompendium.match(spelling),
                "Expected compendium to recognize \(spelling)"
            )
            XCTAssertEqual(match.displayText, spelling)
            XCTAssertTrue(match.symbol.quality.isEmpty)
        }
    }

    func testBasicMajorChordCompendiumNormalizesHandwritingOcrVariants() {
        let expectations = [
            " d flat ": "Db",
            "D FLAT": "Db",
            "F sharp": "F#",
            "c SHARP": "C#",
            "B♭": "Bb",
            "C♭": "Cb",
            "F♯": "F#",
            "A＃": "A#",
            "B flat minor": "Bb-",
            "G sharp min": "G#-",
            "E−": "E-"
        ]

        for (input, expected) in expectations {
            XCTAssertEqual(BasicMajorChordCompendium.match(input)?.displayText, expected, input)
        }

        XCTAssertEqual(BasicMajorChordCompendium.match("Cm7")?.displayText, "C-7")
    }

    func testBasicMajorChordCompendiumRecognizesMinorAliases() {
        for spelling in chromaticSpellings {
            for suffix in ["-", "m", "min", " minor"] {
                XCTAssertEqual(
                    BasicMajorChordCompendium.match("\(spelling)\(suffix)")?.displayText,
                    "\(spelling)-",
                    "\(spelling)\(suffix)"
                )
            }
        }

        XCTAssertEqual(BasicMajorChordCompendium.match("B♭min")?.displayText, "Bb-")
        XCTAssertEqual(BasicMajorChordCompendium.match("F sharp m")?.displayText, "F#-")
    }

    func testBasicMajorChordCompendiumRejectsMajorSuffixAliases() {
        for spelling in chromaticSpellings {
            XCTAssertNil(BasicMajorChordCompendium.match("\(spelling)M"), spelling)
            XCTAssertNil(BasicMajorChordCompendium.match("\(spelling)maj"), spelling)
            XCTAssertNil(BasicMajorChordCompendium.match("\(spelling) major"), spelling)
        }
    }

    func testChordRecognitionCompendiumCandidateOrderingSkipsInvalidCandidates() {
        XCTAssertEqual(
            ChordRecognitionCompendium.match(candidates: ["8b", "Bb"])?.displayText,
            "Bb"
        )
        XCTAssertEqual(
            ChordRecognitionCompendium.match(candidates: ["Cmaj", "C"])?.displayText,
            "C"
        )
        XCTAssertNil(
            ChordRecognitionCompendium.match(candidates: ["8b", "H", "Cmaj7"])
        )
    }

    func testChordRecognitionCompendiumFallsBackToParserForSupportedExtensions() {
        XCTAssertEqual(ChordRecognitionCompendium.match("Cm7")?.displayText, "C-7")
        XCTAssertEqual(ChordRecognitionCompendium.match("Db7b9/D")?.displayText, "Db7b9/D")
        XCTAssertEqual(ChordRecognitionCompendium.match("G/B")?.displayText, "G/B")
        XCTAssertEqual(ChordRecognitionCompendium.match("C△9")?.displayText, "C△9")
        XCTAssertNil(ChordRecognitionCompendium.match("CM7"))
        XCTAssertNil(ChordRecognitionCompendium.match("Cmaj7"))
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

    func testParsesSlashBassWithoutDescriptorBeforeSlash() throws {
        let symbol = try ChordSymbolParser.parse("G/B")

        XCTAssertEqual(symbol.root, .g)
        XCTAssertEqual(symbol.quality, "")
        XCTAssertEqual(symbol.slashBass, "B")
        XCTAssertEqual(symbol.displayText, "G/B")
    }

    func testParsesMinorChordAliasesToJazzMinorQuality() throws {
        for spelling in ["C-", "Cm", "Cmin", "Cminor", "C minor"] {
            let symbol = try ChordSymbolParser.parse(spelling)

            XCTAssertEqual(symbol.displayText, "C-", spelling)
        }

        let extendedMinor = try ChordSymbolParser.parse("Dbmin7")

        XCTAssertEqual(extendedMinor.displayText, "Db-7")
    }

    func testParsesTriangleMajorQualityForExtendedMajorChords() throws {
        let expectations = [
            "C△7": "C△7",
            "CΔ9": "C△9",
            "C∆13": "C△13"
        ]

        for (spelling, expectedDisplayText) in expectations {
            let symbol = try ChordSymbolParser.parse(spelling)

            XCTAssertEqual(symbol.quality, "△", spelling)
            XCTAssertEqual(symbol.displayText, expectedDisplayText, spelling)
        }

        let symbol = ChordSymbol(
            root: .b,
            accidental: .flat,
            quality: "maj",
            extensions: ["7"],
            alterations: [],
            slashBass: nil
        )

        XCTAssertEqual(symbol.displayText, "Bb△7")
    }

    func testParserRejectsUnsupportedMajorSuffixAliases() {
        for spelling in ["CM", "CM7", "Cmaj", "Cmajor", "C major", "Bbmaj7"] {
            XCTAssertThrowsError(try ChordSymbolParser.parse(spelling), spelling)
        }
    }

    func testParsesMeterWithWhitespace() throws {
        let meter = try MeterParser.parse(" 6/8 ")

        XCTAssertEqual(meter.numerator, 6)
        XCTAssertEqual(meter.denominator, 8)
    }
}
