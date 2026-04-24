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

    func testCompleteInitialSetupStoresPromptSelections() {
        var chart = Chart.draft(title: "New Chart")

        chart.completeInitialSetup(
            title: "Pocket Groove",
            key: .bFlatMajor,
            meter: Meter(numerator: 6, denominator: 8),
            staffStyle: .fiveLine
        )

        XCTAssertEqual(chart.title, "Pocket Groove")
        XCTAssertEqual(chart.documentKey, .bFlatMajor)
        XCTAssertEqual(chart.defaultMeter, Meter(numerator: 6, denominator: 8))
        XCTAssertEqual(chart.staffStyle, .fiveLine)
        XCTAssertTrue(chart.hasCompletedInitialSetup)
        XCTAssertEqual(chart.systems.count, 1)
        XCTAssertEqual(chart.systems[0].measures.count, 1)
        XCTAssertEqual(chart.systems[0].measures[0].authoringState, .open)
    }

    func testSetPageHandwrittenNotationDrawingStoresAndClearsRawInk() {
        var chart = Chart.draft(title: "New Chart")
        let drawingData = Data([4, 3, 2, 1])

        XCTAssertTrue(chart.setPageHandwrittenNotationDrawing(drawingData))
        XCTAssertEqual(chart.pageHandwrittenNotationData, drawingData)
        XCTAssertTrue(chart.setPageHandwrittenNotationDrawing(nil))
        XCTAssertNil(chart.pageHandwrittenNotationData)
    }

    func testSetMeasureManualLayoutWidthStoresClampedOverride() throws {
        var chart = Chart.draft(title: "New Chart")
        chart.completeInitialSetup(
            title: "Pocket Groove",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )
        let measureID = try XCTUnwrap(chart.measures.first?.id)

        let appliedLargeWidth = try XCTUnwrap(chart.setMeasureManualLayoutWidth(680, for: measureID))
        XCTAssertEqual(appliedLargeWidth, Measure.maximumManualLayoutWidth)
        XCTAssertEqual(chart.measure(id: measureID)?.manualLayoutWidth, Double(Measure.maximumManualLayoutWidth))

        let appliedSmallWidth = try XCTUnwrap(chart.setMeasureManualLayoutWidth(44, for: measureID))
        XCTAssertEqual(appliedSmallWidth, Measure.minimumManualLayoutWidth)
        XCTAssertEqual(chart.measure(id: measureID)?.manualLayoutWidth, Double(Measure.minimumManualLayoutWidth))

        _ = chart.setMeasureManualLayoutWidth(nil, for: measureID)
        XCTAssertNil(chart.measure(id: measureID)?.manualLayoutWidth)
    }

    func testCommitOpenMeasureMarksCurrentMeasureCommittedAndAppendsNextOpenMeasure() {
        var chart = Chart.draft(title: "New Chart")
        chart.completeInitialSetup(
            title: "Pocket Groove",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )

        let appendedOpenMeasureID = chart.commitOpenMeasure()

        XCTAssertNotNil(appendedOpenMeasureID)
        XCTAssertEqual(chart.measures.count, 2)
        XCTAssertEqual(chart.measures[0].authoringState, .committed)
        XCTAssertEqual(chart.measures[1].authoringState, .open)
        XCTAssertEqual(chart.measures[1].index, 2)
    }

    func testPositionOpenMeasureAfterCommittedMeasureMovesBlankOpenSlotBehindSelection() throws {
        var chart = Chart.draft(title: "New Chart")
        chart.completeInitialSetup(
            title: "Pocket Groove",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )

        let firstMeasureID = try XCTUnwrap(chart.measures.first?.id)
        let secondMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        let trailingOpenMeasureID = try XCTUnwrap(chart.commitOpenMeasure())

        let repositionedOpenMeasureID = try XCTUnwrap(chart.positionOpenMeasure(after: firstMeasureID))

        XCTAssertEqual(repositionedOpenMeasureID, trailingOpenMeasureID)
        XCTAssertEqual(chart.measures.map(\.id), [firstMeasureID, trailingOpenMeasureID, secondMeasureID])
        XCTAssertEqual(chart.measure(id: trailingOpenMeasureID)?.authoringState, .open)
        XCTAssertEqual(chart.measure(id: secondMeasureID)?.authoringState, .committed)
    }

    func testPositionOpenMeasureKeepsNonBlankOpenMeasureInPlace() throws {
        var chart = Chart.draft(title: "New Chart")
        chart.completeInitialSetup(
            title: "Pocket Groove",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )

        let firstMeasureID = try XCTUnwrap(chart.measures.first?.id)
        let secondMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        let trailingOpenMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        chart.systems[0].measures[2].chordEvents = [demoChordEvent(root: .c)]

        let resolvedOpenMeasureID = try XCTUnwrap(chart.positionOpenMeasure(after: firstMeasureID))

        XCTAssertEqual(resolvedOpenMeasureID, trailingOpenMeasureID)
        XCTAssertEqual(chart.measures.map(\.id), [firstMeasureID, secondMeasureID, trailingOpenMeasureID])
        XCTAssertEqual(chart.measure(id: trailingOpenMeasureID)?.authoringState, .open)
        XCTAssertEqual(chart.measure(id: secondMeasureID)?.authoringState, .committed)
    }

    func testPositionOpenMeasureReanchorsAnnotationsWhenLaterMeasureShiftsSystems() throws {
        let firstSystemID = UUID()
        let secondSystemID = UUID()
        let measure1 = makeMeasure(index: 1)
        let measure2 = makeMeasure(index: 2)
        let measure3 = makeMeasure(index: 3)
        let annotatedMeasure = makeMeasure(index: 4, barlineAfter: .double)
        let laterMeasure = makeMeasure(index: 5)
        let openMeasure = makeMeasure(index: 6, authoringState: .open)

        var chart = Chart(
            id: UUID(),
            title: "Anchored Chart",
            chartType: .chordChart,
            documentKey: .cMajor,
            documentFont: .classic,
            defaultTranspositionView: .concert,
            defaultMeter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine,
            hasCompletedInitialSetup: true,
            systems: [
                ChartSystem(
                    id: firstSystemID,
                    index: 0,
                    spacingMode: .automatic,
                    lineBreakRule: .automatic,
                    measures: [measure1, measure2, measure3, annotatedMeasure]
                ),
                ChartSystem(
                    id: secondSystemID,
                    index: 1,
                    spacingMode: .automatic,
                    lineBreakRule: .automatic,
                    measures: [laterMeasure, openMeasure]
                )
            ],
            sectionLabels: [
                SectionLabel(
                    id: UUID(),
                    text: "B",
                    type: .sectionName,
                    anchorMeasureID: annotatedMeasure.id,
                    anchorSystemID: firstSystemID,
                    rawInput: "B"
                )
            ],
            cueTexts: [],
            roadmapObjects: [
                RoadmapObject(
                    id: UUID(),
                    type: .dc,
                    startMeasureID: annotatedMeasure.id,
                    endMeasureID: nil,
                    anchorSystemID: firstSystemID,
                    placement: .floatingTop,
                    displayText: nil,
                    count: nil,
                    linkedTargetID: nil,
                    rawInput: "D.C."
                )
            ],
            stylePreset: .cleanStudio,
            createdAt: .now,
            updatedAt: .now
        )

        let repositionedOpenMeasureID = try XCTUnwrap(chart.positionOpenMeasure(after: measure1.id))

        XCTAssertEqual(repositionedOpenMeasureID, openMeasure.id)
        XCTAssertEqual(chart.measures[0].id, measure1.id)
        XCTAssertEqual(chart.measures[1].id, openMeasure.id)
        XCTAssertEqual(chart.measure(id: annotatedMeasure.id)?.index, 5)
        XCTAssertEqual(chart.sectionLabels.first?.anchorSystemID, secondSystemID)
        XCTAssertEqual(chart.roadmapObjects.first?.anchorSystemID, secondSystemID)
    }

    func testApplyMeterChangeToNextTimeSignaturePersistsIntoFutureMeasures() throws {
        var chart = Chart.draft(title: "Time Changes")
        chart.completeInitialSetup(
            title: "Time Changes",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )
        let firstMeasureID = try XCTUnwrap(chart.measures.first?.id)
        let secondMeasureID = try XCTUnwrap(chart.commitOpenMeasure())

        let changedMeasureID = try XCTUnwrap(
            chart.applyMeterChange(
                Meter(numerator: 3, denominator: 4),
                after: firstMeasureID,
                scope: .toNextTimeSignature
            )
        )
        let appendedMeasureID = try XCTUnwrap(chart.commitOpenMeasure())

        XCTAssertEqual(changedMeasureID, secondMeasureID)
        XCTAssertNil(chart.measure(id: firstMeasureID)?.meterOverride)
        XCTAssertEqual(chart.measure(id: secondMeasureID)?.meterOverride, Meter(numerator: 3, denominator: 4))
        XCTAssertEqual(chart.measure(id: appendedMeasureID)?.meterOverride, Meter(numerator: 3, denominator: 4))
    }

    func testApplyMeterChangeFixedMeasureCountRestoresSourceMeterAfterSpecifiedSpan() throws {
        var chart = Chart.draft(title: "Time Changes")
        chart.completeInitialSetup(
            title: "Time Changes",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )
        let firstMeasureID = try XCTUnwrap(chart.measures.first?.id)
        _ = chart.applyMeterChange(
            Meter(numerator: 3, denominator: 4),
            after: firstMeasureID,
            scope: .fixedMeasureCount(1)
        )

        XCTAssertEqual(chart.measures.count, 3)
        XCTAssertEqual(chart.measures[1].meterOverride, Meter(numerator: 3, denominator: 4))
        XCTAssertEqual(chart.measures[2].meterOverride, Meter(numerator: 3, denominator: 4))

        let revertedMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        XCTAssertNil(chart.measure(id: revertedMeasureID)?.meterOverride)
    }

    func testApplyMeterChangeToEndOfPieceOverridesLaterTimeSignatures() throws {
        var chart = Chart.draft(title: "Time Changes")
        chart.completeInitialSetup(
            title: "Time Changes",
            key: .cMajor,
            meter: Meter(numerator: 4, denominator: 4),
            staffStyle: .fiveLine
        )
        let firstMeasureID = try XCTUnwrap(chart.measures.first?.id)
        let secondMeasureID = try XCTUnwrap(chart.commitOpenMeasure())
        _ = chart.commitOpenMeasure()

        _ = chart.applyMeterChange(
            Meter(numerator: 5, denominator: 4),
            after: secondMeasureID,
            scope: .toNextTimeSignature
        )
        _ = chart.applyMeterChange(
            Meter(numerator: 3, denominator: 4),
            after: firstMeasureID,
            scope: .toEndOfPiece
        )

        XCTAssertEqual(chart.measures[1].meterOverride, Meter(numerator: 3, denominator: 4))
        XCTAssertEqual(chart.measures[2].meterOverride, Meter(numerator: 3, denominator: 4))
        XCTAssertTrue(chart.timeSignatureChanges.allSatisfy { $0.afterMeasureID == firstMeasureID })
    }

    private func makeMeasure(
        index: Int,
        barlineAfter: BarlineType = .single,
        authoringState: MeasureAuthoringState = .committed
    ) -> Measure {
        Measure(
            id: UUID(),
            index: index,
            meterOverride: nil,
            beatGridPreset: .simple,
            barlineAfter: barlineAfter,
            chordEvents: [],
            cueTextIDs: [],
            roadmapObjectIDs: [],
            authoringState: authoringState
        )
    }

    private func demoChordEvent(root: ChordRoot) -> ChordEvent {
        ChordEvent(
            id: UUID(),
            symbol: ChordSymbol(root: root, accidental: .natural, quality: "7", extensions: [], alterations: [], slashBass: nil),
            startPosition: BeatPosition(beat: 1, subdivision: 0, subdivisionsPerBeat: 2),
            duration: .quarter,
            rhythmPlacement: .belowChord,
            tieOut: false,
            hitStyle: .none,
            rawInput: nil
        )
    }
}
