import XCTest
@testable import SmartChart

final class ChartEditingTests: XCTestCase {
    func testAddCueTextUpdatesChartAndMeasure() {
        var chart = Chart.blank(title: "Test Chart")

        chart.addCueText("hits")

        XCTAssertEqual(chart.cueTexts.count, 1)
        XCTAssertEqual(chart.cueTexts.first?.text, "hits")
        XCTAssertEqual(chart.systems[0].measures[0].cueTextIDs, [chart.cueTexts[0].id])
    }

    func testAddRoadmapObjectUpdatesChartAndMeasure() {
        var chart = Chart.blank(title: "Test Chart")

        chart.addRoadmapObject(.dcAlFine)

        XCTAssertEqual(chart.roadmapObjects.count, 1)
        XCTAssertEqual(chart.roadmapObjects.first?.type, .dcAlFine)
        XCTAssertEqual(chart.systems[0].measures[0].roadmapObjectIDs, [chart.roadmapObjects[0].id])
    }

    func testDocumentKeyTransposesForBbView() {
        let displayedKey = DocumentKey.cMajor.transposed(for: .bb)

        XCTAssertEqual(displayedKey.tonic, .d)
        XCTAssertEqual(displayedKey.accidental, .natural)
        XCTAssertEqual(displayedKey.mode, .major)
    }
}
