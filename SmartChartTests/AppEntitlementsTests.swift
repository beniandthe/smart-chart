import XCTest
@testable import SmartChart

final class AppEntitlementsTests: XCTestCase {
    func testFreePlanCapsLocalChartsAndLocksPremiumFeatures() {
        let entitlements = AppEntitlements.free

        XCTAssertEqual(entitlements.localChartLimit, 5)
        XCTAssertTrue(entitlements.canCreateChart(currentChartCount: 4))
        XCTAssertFalse(entitlements.canCreateChart(currentChartCount: 5))
        XCTAssertFalse(entitlements.includes(.pdfExport))
        XCTAssertFalse(entitlements.includes(.documentTransposition))
    }

    func testProPlanUnlocksPermanentLocalAuthoringFeatures() {
        let entitlements = AppEntitlements(activePlan: .proLifetime)

        XCTAssertNil(entitlements.localChartLimit)
        XCTAssertTrue(entitlements.includes(.unlimitedLocalCharts))
        XCTAssertTrue(entitlements.includes(.pdfExport))
        XCTAssertTrue(entitlements.includes(.fontPresets))
        XCTAssertTrue(entitlements.includes(.advancedRhythmEditing))
        XCTAssertFalse(entitlements.includes(.cloudBackup))
    }

    func testStudioPlanAddsServiceBackedFeaturesOnTopOfPro() {
        let entitlements = AppEntitlements(activePlan: .studioSubscription)

        XCTAssertTrue(entitlements.includes(.syncedChartOrganization))
        XCTAssertTrue(entitlements.includes(.cloudBackup))
        XCTAssertTrue(entitlements.includes(.sharedBandLibraries))
        XCTAssertTrue(entitlements.includes(.setlistsAndVersionHistory))
        XCTAssertTrue(entitlements.includes(.aiRecognitionCleanup))
    }
}
