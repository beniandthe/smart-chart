import Foundation

protocol ChartExporting {
    func exportPDF(for chart: Chart) async throws -> URL
}

struct PlaceholderChartExporter: ChartExporting {
    enum ExportError: Error {
        case notImplemented
    }

    func exportPDF(for chart: Chart) async throws -> URL {
        _ = chart
        throw ExportError.notImplemented
    }
}
