#if canImport(UIKit)
import Foundation
import XCTest
@testable import SmartChart

final class PDFChartExporterTests: XCTestCase {
    func testExportPDFWritesAValidLookingPDFFile() async throws {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exporter = PDFChartExporter(exportDirectory: exportDirectory)

        defer {
            try? FileManager.default.removeItem(at: exportDirectory)
        }

        let exportedURL = try await exporter.exportPDF(for: ChartSamples.syncopatedFunkGroove)
        let data = try Data(contentsOf: exportedURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedURL.path))
        XCTAssertEqual(String(data: data.prefix(4), encoding: .utf8), "%PDF")
        XCTAssertGreaterThan(data.count, 2_000)
    }
}
#endif
