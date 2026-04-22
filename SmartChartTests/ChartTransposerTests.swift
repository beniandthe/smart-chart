import XCTest
@testable import SmartChart

final class ChartTransposerTests: XCTestCase {
    func testTransposesConcertChordForBbView() throws {
        let symbol = try ChordSymbolParser.parse("Cmaj7")
        let transposed = symbol.transposed(by: TranspositionView.bb.semitoneOffsetFromConcert)

        XCTAssertEqual(transposed.displayText, "Dmaj7")
    }

    func testTransposesConcertChordForEbView() throws {
        let symbol = try ChordSymbolParser.parse("C7")
        let transposed = symbol.transposed(by: TranspositionView.eb.semitoneOffsetFromConcert)

        XCTAssertEqual(transposed.displayText, "A7")
    }

    func testTransposesWholeChartWithoutChangingTiming() {
        let chart = ChartSamples.syncopatedFunkGroove
        let transposed = ChartTransposer.transposedChart(chart, for: .bb)

        XCTAssertEqual(transposed.defaultTranspositionView, .bb)
        XCTAssertEqual(transposed.systems[0].measures[0].chordEvents[0].symbol.displayText, "Fmaj7")
        XCTAssertEqual(
            transposed.systems[0].measures[0].chordEvents[0].startPosition,
            chart.systems[0].measures[0].chordEvents[0].startPosition
        )
    }
}
