import XCTest
@testable import SmartChart

final class StrokeClustererTests: XCTestCase {
    private let clusterer = StrokeClusterer()

    func testClustersPlanAcceptanceFixturesIntoGlyphSizedGroups() throws {
        for fixture in try InkFixtureLoader.loadAll(file: #filePath) {
            guard let expectedClusterCount = fixture.expectedClusterCount else {
                continue
            }

            let clusters = clusterer.cluster(fixture.strokes)

            XCTAssertEqual(
                clusters.count,
                expectedClusterCount,
                "Expected \(fixture.name) to split into \(fixture.expectedTopGlyphs)"
            )
            XCTAssertEqual(clusters.count, fixture.expectedTopGlyphs.count)
            XCTAssertTrue(clusters.areSortedLeftToRight)
            XCTAssertEqual(
                clusters.reduce(0) { $0 + $1.strokes.count },
                fixture.strokes.count
            )
        }
    }

    func testClustererOutputIsDeterministicForReorderedInput() throws {
        let fixture = try InkFixtureLoader.load("Db7b9", file: #filePath)

        let forwardClusters = clusterer.cluster(fixture.strokes)
        let reversedClusters = clusterer.cluster(Array(fixture.strokes.reversed()))

        XCTAssertEqual(forwardClusters.map(\.bounds), reversedClusters.map(\.bounds))
        XCTAssertEqual(forwardClusters.map(\.strokes.count), reversedClusters.map(\.strokes.count))
    }

    func testSlashBassKeepsSlashAsSeparatorCluster() throws {
        let fixture = try InkFixtureLoader.load("GSlashB", file: #filePath)
        let clusters = clusterer.cluster(fixture.strokes)

        XCTAssertEqual(clusters.count, fixture.expectedClusterCount)
        XCTAssertEqual(clusters.count, fixture.expectedTopGlyphs.count)
        XCTAssertEqual(clusters[1].strokes.count, 1)
        XCTAssertGreaterThan(clusters[1].bounds.height, clusters[1].bounds.width)
        XCTAssertTrue(clusters.areSortedLeftToRight)
    }

    func testLongTimeGapPreventsMergingEvenWhenGeometryIsNear() {
        let firstStroke = InkStroke(
            points: [
                InkPoint(x: 10, y: 10, timeOffset: 0.0),
                InkPoint(x: 10, y: 50, timeOffset: 0.1)
            ]
        )
        let secondStroke = InkStroke(
            points: [
                InkPoint(x: 13, y: 10, timeOffset: 1.2),
                InkPoint(x: 13, y: 50, timeOffset: 1.3)
            ]
        )

        let clusters = clusterer.cluster([firstStroke, secondStroke])

        XCTAssertEqual(clusters.count, 2)
    }
}

private extension [InkCluster] {
    var areSortedLeftToRight: Bool {
        zip(self, dropFirst()).allSatisfy { lhs, rhs in
            lhs.bounds.minX <= rhs.bounds.minX
        }
    }
}
