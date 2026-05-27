#if canImport(UIKit)
import PencilKit
import XCTest
@testable import SmartChart

final class LeadSheetInteractionModeStatePolicyTests: XCTestCase {
    func testChordEntryUsesPersistentMonolineInk() {
        let policy = LeadSheetInteractionModeStatePolicy.resolve(for: .chordEntry)

        XCTAssertEqual(policy.inkTool.inkType, .monoline)
        XCTAssertEqual(policy.inkTool.width, 2.8, accuracy: 0.001)
    }
}
#endif
