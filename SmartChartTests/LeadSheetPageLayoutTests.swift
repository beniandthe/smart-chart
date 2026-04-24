import CoreGraphics
import XCTest
@testable import SmartChart

final class LeadSheetPageLayoutTests: XCTestCase {
    func testFiveLineLayoutCreatesCenteredPaperAndHeader() {
        let chart = ChartSamples.straightAheadSwing

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 1180, height: 1500)
        )

        XCTAssertGreaterThan(layout.paperFrame.width, 600)
        XCTAssertLessThan(layout.paperFrame.minX, layout.pageBounds.midX)
        XCTAssertGreaterThan(layout.paperFrame.maxX, layout.pageBounds.midX)
        XCTAssertTrue(layout.paperFrame.contains(layout.header.titleFrame))
        XCTAssertTrue(layout.header.titleFrame.midX > layout.paperFrame.minX)
    }

    func testFiveLineLayoutPlacesChordTextAboveStaffAndBuildsNoteGlyphs() throws {
        let chart = ChartSamples.straightAheadSwing

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 1180, height: 1500)
        )

        let firstSystem = try XCTUnwrap(layout.systems.first)
        let firstMeasure = try XCTUnwrap(firstSystem.measures.first)
        let firstChord = try XCTUnwrap(firstMeasure.chordLayouts.first)
        let firstNote = try XCTUnwrap(firstMeasure.noteLayouts.first)

        XCTAssertLessThan(firstChord.frame.maxY, firstMeasure.staffFrame.minY)
        XCTAssertTrue(firstMeasure.staffFrame.contains(firstNote.noteheadFrame))
        XCTAssertNotNil(firstNote.stemStart)
        XCTAssertNotNil(firstNote.stemEnd)
    }

    func testOpenFiveLineMeasureUsesSingleOpenMeasureWidthAndNoCommittedBarline() throws {
        var chart = Chart.draft(title: "Blank Lead Sheet")
        chart.completeInitialSetup(
            title: "Blank Lead Sheet",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        let firstSystem = try XCTUnwrap(layout.systems.first)
        let firstMeasure = try XCTUnwrap(firstSystem.measures.first)

        XCTAssertTrue(firstMeasure.isOpen)
        XCTAssertEqual(firstSystem.measures.count, 1)
        XCTAssertGreaterThan(firstMeasure.frame.width, 220)
        XCTAssertLessThan(firstMeasure.frame.width, 280)
        XCTAssertLessThan(firstSystem.frame.width, layout.paperFrame.width * 0.55)
        XCTAssertLessThanOrEqual(abs(firstMeasure.trailingBarlineFrame.midX - firstSystem.frame.maxX), 12)
        XCTAssertTrue(firstMeasure.noteLayouts.isEmpty)
    }

    func testLeadSheetLayoutKeepsGrowingMeasuresOnFirstSystemBeforeWrapping() throws {
        var chart = makeBlankLeadSheet()
        _ = chart.commitOpenMeasure()
        _ = chart.commitOpenMeasure()

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        XCTAssertEqual(layout.systems.count, 1)

        let firstSystem = try XCTUnwrap(layout.systems.first)
        XCTAssertEqual(firstSystem.measures.count, 3)
        XCTAssertGreaterThan(firstSystem.frame.width, 520)
        XCTAssertLessThan(firstSystem.frame.width, layout.paperFrame.width)
        XCTAssertTrue(firstSystem.measures[2].isOpen)
        XCTAssertLessThan(firstSystem.measures[0].frame.width, firstSystem.measures[2].frame.width)
    }

    func testLeadSheetLayoutWrapsOpenMeasureOntoNextSystemWhenLineFills() throws {
        var chart = makeBlankLeadSheet()
        _ = chart.commitOpenMeasure()
        _ = chart.commitOpenMeasure()
        _ = chart.commitOpenMeasure()

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        XCTAssertEqual(layout.systems.count, 2)

        let firstSystem = try XCTUnwrap(layout.systems.first)
        let secondSystem = try XCTUnwrap(layout.systems.last)

        XCTAssertEqual(firstSystem.measures.count, 3)
        XCTAssertEqual(secondSystem.measures.count, 1)
        XCTAssertTrue(secondSystem.measures[0].isOpen)
        XCTAssertGreaterThan(secondSystem.measures[0].frame.width, 220)
        XCTAssertLessThan(secondSystem.frame.width, layout.paperFrame.width * 0.5)
    }

    func testLeadSheetLayoutHonorsManualMeasureWidthOverride() throws {
        var chart = makeBlankLeadSheet()
        let measureID = try XCTUnwrap(chart.measures.first?.id)
        _ = chart.setMeasureManualLayoutWidth(320, for: measureID)

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        let firstSystem = try XCTUnwrap(layout.systems.first)
        let firstMeasure = try XCTUnwrap(firstSystem.measures.first)
        XCTAssertGreaterThan(firstMeasure.frame.width, 300)
        XCTAssertLessThan(firstSystem.frame.width, layout.paperFrame.width * 0.7)
    }

    func testLeadSheetLayoutWrapsEarlierWhenCommittedMeasureIsStretched() throws {
        var chart = makeBlankLeadSheet()
        let firstOpenID = try XCTUnwrap(chart.measures.first?.id)
        _ = chart.commitOpenMeasure()
        _ = chart.commitOpenMeasure()
        _ = chart.commitOpenMeasure()
        _ = chart.setMeasureManualLayoutWidth(400, for: firstOpenID)

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        XCTAssertEqual(layout.systems.count, 2)
        let firstSystem = try XCTUnwrap(layout.systems.first)
        let secondSystem = try XCTUnwrap(layout.systems.last)
        XCTAssertEqual(firstSystem.measures.count, 2)
        XCTAssertEqual(secondSystem.measures.count, 2)
    }

    func testLeadSheetLayoutShowsTrailingMeterChangeAtEndOfSelectedMeasure() throws {
        var chart = makeBlankLeadSheet()
        _ = chart.commitOpenMeasure()
        let thirdMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        _ = chart.applyMeterChange(
            Meter(numerator: 3, denominator: 4),
            after: thirdMeasureID,
            scope: .toNextTimeSignature
        )

        let layout = LeadSheetPageLayoutEngine.pageLayout(
            for: chart,
            pageSize: CGSize(width: 900, height: 1400)
        )

        let firstSystem = try XCTUnwrap(layout.systems.first)
        let trailingChangeMeasure = try XCTUnwrap(firstSystem.measures.last)

        XCTAssertEqual(trailingChangeMeasure.sourceMeasureID, thirdMeasureID)
        XCTAssertEqual(trailingChangeMeasure.trailingMeterChange, Meter(numerator: 3, denominator: 4))
        XCTAssertNotNil(trailingChangeMeasure.trailingMeterChangeFrame)
    }

    private func makeBlankLeadSheet() -> Chart {
        var chart = Chart.draft(title: "Blank Lead Sheet")
        chart.completeInitialSetup(
            title: "Blank Lead Sheet",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )
        return chart
    }
}
