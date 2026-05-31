import XCTest
@testable import SmartChart

final class FileChartRepositoryTests: XCTestCase {
    func testLoadSnapshotReturnsNilWhenFileDoesNotExist() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = FileChartRepository(
            url: temporaryDirectory.appendingPathComponent("library-state.json")
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        XCTAssertNil(try repository.loadSnapshot())
    }

    func testRoundTripsSnapshotToDisk() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = FileChartRepository(
            url: temporaryDirectory.appendingPathComponent("library-state.json")
        )
        let snapshot = ChartLibrarySnapshot(
            charts: ChartSamples.previewCharts,
            selectedChartID: ChartSamples.previewCharts.last?.id,
            entitlements: AppEntitlements(activePlan: .proLifetime)
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        try repository.saveSnapshot(snapshot)
        let loadedSnapshot = try XCTUnwrap(repository.loadSnapshot())

        XCTAssertEqual(loadedSnapshot, snapshot)
    }

    func testRoundTripsSnapshotWhenPathContainsSpaces() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let repository = FileChartRepository(
            url: temporaryDirectory.appendingPathComponent("library-state.json")
        )
        let snapshot = ChartLibrarySnapshot(
            charts: [Chart.blank(title: "Chord Writing Test Chart", key: .cMajor)],
            selectedChartID: nil,
            entitlements: AppEntitlements(activePlan: .free)
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory.deletingLastPathComponent())
        }

        try repository.saveSnapshot(snapshot)
        let loadedSnapshot = try XCTUnwrap(repository.loadSnapshot())

        XCTAssertEqual(loadedSnapshot, snapshot)
    }

    func testRoundTripsV1SimpleChordSheetAuthoringStateToDisk() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = FileChartRepository(
            url: temporaryDirectory.appendingPathComponent("library-state.json")
        )
        var chart = Chart.blank(
            title: "Simple V1 Persistence",
            measureCount: 4,
            layoutStyle: .simpleChordSheet
        )
        chart.composerCredit = "Composer"
        chart.styleNote = "Medium Swing"
        chart.setMatchedFontFamily(.museJazz)
        chart.setChordFontOverride(.finaleJazz)
        chart.setHeaderFontOverride(.leland)
        chart.setTextFontOverride(.petaluma)
        let measureIDs = chart.measures.map(\.id)
        chart.addSectionLabel(text: "A")
        XCTAssertTrue(chart.insertSimpleSystemBreak(before: measureIDs[2]))
        XCTAssertEqual(chart.setMeasureManualLayoutWidth(180, for: measureIDs[0]), 180)
        _ = try XCTUnwrap(
            chart.addRepeatSpan(startMeasureID: measureIDs[0], endMeasureID: measureIDs[3])
        )
        _ = try XCTUnwrap(
            chart.addEndingSpan(.ending1, startMeasureID: measureIDs[0], endMeasureID: measureIDs[1])
        )
        _ = try XCTUnwrap(
            chart.addPointRoadmapMarker(.fine, anchorMeasureID: measureIDs[3])
        )
        _ = try XCTUnwrap(
            chart.addCueText("freely", anchorMeasureID: measureIDs[1], position: .above, emphasis: .subtle)
        )
        _ = try XCTUnwrap(
            chart.addFreehandSymbol(
                anchorMeasureID: measureIDs[1],
                lane: .chartArea,
                normalizedFrame: FreehandSymbolNormalizedFrame(x: 0.12, y: 0.18, width: 0.2, height: 0.1),
                measureRelativeFrame: FreehandSymbolMeasureFrame(offsetX: 12, offsetY: -18, width: 34, height: 16),
                drawingData: Data([9, 7, 5, 3])
            )
        )
        XCTAssertTrue(
            chart.appendRecognizedChord(
                try ChordSymbolParser.parse("Bb△7"),
                rawInput: "Bb△7",
                to: measureIDs[0],
                atFraction: 0.05
            )
        )
        XCTAssertTrue(
            chart.appendRecognizedChord(
                try ChordSymbolParser.parse("D-7"),
                rawInput: "D-7",
                to: measureIDs[0],
                atFraction: 0.86
            )
        )
        let snapshot = ChartLibrarySnapshot(
            charts: [chart],
            selectedChartID: chart.id,
            entitlements: AppEntitlements(activePlan: .proLifetime)
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        try repository.saveSnapshot(snapshot)
        let loadedSnapshot = try XCTUnwrap(repository.loadSnapshot())
        let loadedChart = try XCTUnwrap(loadedSnapshot.charts.first)

        XCTAssertEqual(loadedSnapshot, snapshot)
        XCTAssertEqual(loadedSnapshot.selectedChartID, chart.id)
        XCTAssertEqual(loadedChart.layoutStyle, .simpleChordSheet)
        XCTAssertEqual(loadedChart.typography.matchedSet, .museJazz)
        XCTAssertEqual(loadedChart.typography.chordOverride, .finaleJazz)
        XCTAssertEqual(loadedChart.typography.headerOverride, .leland)
        XCTAssertEqual(loadedChart.typography.textOverride, .petaluma)
        XCTAssertEqual(loadedChart.systems.count, 2)
        XCTAssertEqual(loadedChart.systems[1].lineBreakRule, .forced)
        XCTAssertEqual(loadedChart.measures.map(\.id), measureIDs)
        XCTAssertEqual(loadedChart.measure(id: measureIDs[0])?.manualLayoutWidth, 180)
        XCTAssertEqual(loadedChart.sectionLabels.first?.text, "A")
        XCTAssertEqual(loadedChart.cueTexts.first?.text, "freely")
        XCTAssertEqual(loadedChart.cueTexts.first?.position, .above)
        XCTAssertEqual(Set(loadedChart.roadmapObjects.map(\.type)), [.repeatSpan, .ending1, .fine])
        XCTAssertEqual(loadedChart.freehandSymbols.first?.lane, .chartArea)
        XCTAssertEqual(loadedChart.freehandSymbols.first?.anchorMeasureID, measureIDs[1])
        XCTAssertEqual(loadedChart.measure(id: measureIDs[0])?.chordEvents.map(\.rawInput), ["Bb△7", "D-7"])
    }
}
