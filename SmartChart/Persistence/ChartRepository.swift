import Foundation

protocol ChartRepository {
    func loadCharts() throws -> [Chart]
    func saveCharts(_ charts: [Chart]) throws
}

struct InMemoryChartRepository: ChartRepository {
    func loadCharts() throws -> [Chart] {
        ChartSamples.previewCharts
    }

    func saveCharts(_ charts: [Chart]) throws {
        _ = charts
    }
}
