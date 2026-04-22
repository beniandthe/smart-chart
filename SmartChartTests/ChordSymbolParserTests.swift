import XCTest
@testable import SmartChart

final class ChordSymbolParserTests: XCTestCase {
    func testParsesChordWithExtensionAlterationAndSlashBass() throws {
        let symbol = try ChordSymbolParser.parse("Bb7b9/D")

        XCTAssertEqual(symbol.root, .b)
        XCTAssertEqual(symbol.accidental, .flat)
        XCTAssertEqual(symbol.quality, "")
        XCTAssertEqual(symbol.extensions, ["7"])
        XCTAssertEqual(symbol.alterations, ["b9"])
        XCTAssertEqual(symbol.slashBass, "D")
    }

    func testParsesMeterWithWhitespace() throws {
        let meter = try MeterParser.parse(" 6/8 ")

        XCTAssertEqual(meter.numerator, 6)
        XCTAssertEqual(meter.denominator, 8)
    }
}
