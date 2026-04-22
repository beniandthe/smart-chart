import Combine
import Foundation

final class ChartLibraryStore: ObservableObject {
    @Published var charts: [Chart]
    @Published var selectedChartID: Chart.ID?
    @Published var entitlements: AppEntitlements

    init(charts: [Chart], entitlements: AppEntitlements = .free) {
        self.charts = charts
        self.entitlements = entitlements
        self.selectedChartID = charts.first?.id
    }

    var canCreateChart: Bool {
        entitlements.canCreateChart(currentChartCount: charts.count)
    }

    var chartCapacityText: String {
        entitlements.chartCapacityText(currentChartCount: charts.count)
    }

    var planSummaryText: String {
        entitlements.activePlan.summaryText
    }

    var upgradeSummaryText: String {
        entitlements.upgradeSummaryText
    }

    func canUse(_ feature: EntitledFeature) -> Bool {
        entitlements.includes(feature)
    }

    func setPlan(_ plan: SmartChartPlan) {
        entitlements.activePlan = plan
    }

    @discardableResult
    func createBlankChart(in key: DocumentKey = .cMajor) -> Bool {
        guard canCreateChart else {
            return false
        }

        let newChart = Chart.blank(title: "New Chart \(charts.count + 1)", key: key)
        charts.insert(newChart, at: 0)
        selectedChartID = newChart.id
        return true
    }

    static var preview: ChartLibraryStore {
        ChartLibraryStore(charts: ChartSamples.previewCharts)
    }
}
