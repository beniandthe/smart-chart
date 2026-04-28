import XCTest
@testable import SmartChart

final class ChartLibraryStoreTests: XCTestCase {
    private final class RecordingChartRepository: ChartRepository {
        var snapshotToLoad: ChartLibrarySnapshot?
        private(set) var savedSnapshots: [ChartLibrarySnapshot] = []

        func loadSnapshot() throws -> ChartLibrarySnapshot? {
            snapshotToLoad
        }

        func saveSnapshot(_ snapshot: ChartLibrarySnapshot) throws {
            savedSnapshots.append(snapshot)
        }
    }

    func testFreePlanPreventsCreatingPastTheChartLimit() {
        let charts = (1...AppEntitlements.recommendedFreeChartLimit).map {
            Chart.blank(title: "Chart \($0)")
        }
        let store = ChartLibraryStore(charts: charts, entitlements: .free)

        let didCreateChart = store.createBlankChart()

        XCTAssertFalse(didCreateChart)
        XCTAssertEqual(store.charts.count, AppEntitlements.recommendedFreeChartLimit)
    }

    func testProPlanAllowsCreatingMoreCharts() {
        let charts = (1...AppEntitlements.recommendedFreeChartLimit).map {
            Chart.blank(title: "Chart \($0)")
        }
        let store = ChartLibraryStore(
            charts: charts,
            entitlements: AppEntitlements(activePlan: .proLifetime)
        )

        let didCreateChart = store.createBlankChart(in: .bFlatMajor)

        XCTAssertTrue(didCreateChart)
        XCTAssertEqual(store.charts.count, AppEntitlements.recommendedFreeChartLimit + 1)
        XCTAssertEqual(store.charts.first?.documentKey, .bFlatMajor)
    }

    func testSetPlanUpdatesActiveEntitlements() {
        let store = ChartLibraryStore(charts: ChartSamples.previewCharts, entitlements: .free)

        store.setPlan(.studioSubscription)

        XCTAssertEqual(store.entitlements.activePlan, .studioSubscription)
        XCTAssertTrue(store.canUse(.cloudBackup))
    }

    func testCreateBlankChartPersistsUpdatedSnapshot() {
        let repository = RecordingChartRepository()
        let store = ChartLibraryStore(
            charts: ChartSamples.previewCharts,
            repository: repository
        )

        let didCreateChart = store.createBlankChart(in: .gMajor)

        XCTAssertTrue(didCreateChart)
        XCTAssertEqual(repository.savedSnapshots.last?.charts.first?.documentKey, .gMajor)
        XCTAssertEqual(repository.savedSnapshots.last?.selectedChartID, store.selectedChartID)
    }

    func testCreateBlankChartCreatesUnconfiguredDraftPage() {
        let store = ChartLibraryStore(charts: ChartSamples.previewCharts)

        let didCreateChart = store.createBlankChart()

        XCTAssertTrue(didCreateChart)
        XCTAssertEqual(store.charts.first?.measures.count, 0)
        XCTAssertEqual(store.charts.first?.systems.count, 0)
        XCTAssertEqual(store.charts.first?.hasCompletedInitialSetup, false)
    }

    func testSetPlanPersistsEntitlementsSnapshot() {
        let repository = RecordingChartRepository()
        let store = ChartLibraryStore(
            charts: ChartSamples.previewCharts,
            repository: repository
        )

        store.setPlan(.proLifetime)

        XCTAssertEqual(repository.savedSnapshots.last?.entitlements.activePlan, .proLifetime)
    }

    func testSnapshotInitializerPreservesValidSelection() {
        let charts = ChartSamples.previewCharts
        let snapshot = ChartLibrarySnapshot(
            charts: charts,
            selectedChartID: charts.last?.id,
            entitlements: .free
        )

        let store = ChartLibraryStore(snapshot: snapshot)

        XCTAssertEqual(store.selectedChartID, charts.last?.id)
    }

    func testUniversalRhythmGuideSupportsExpectedReferenceSymbols() {
        XCTAssertEqual(
            Set(RhythmicNotationPrimitive.supportedUniversalGuidePrimitives),
            Set([
                .wholeNote,
                .halfNote,
                .dottedHalfNote,
                .quarterNote,
                .slash,
                .dottedQuarterNote,
                .eighthNote,
                .wholeRest,
                .quarterRest,
                .halfRest,
                .eighthRest
            ])
        )
        XCTAssertEqual(
            Set(RhythmicNotationPrimitive.pendingUniversalGuidePrimitives),
            Set([.tie])
        )
    }
}
