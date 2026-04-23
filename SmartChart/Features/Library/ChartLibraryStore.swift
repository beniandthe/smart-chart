import Combine
import Foundation

final class ChartLibraryStore: ObservableObject {
    @Published var charts: [Chart] {
        didSet { persistIfNeeded() }
    }
    @Published var selectedChartID: Chart.ID? {
        didSet { persistIfNeeded() }
    }
    @Published var entitlements: AppEntitlements {
        didSet { persistIfNeeded() }
    }

    private let repository: ChartRepository?
    private var persistenceEnabled = false

    init(
        charts: [Chart],
        entitlements: AppEntitlements = .free,
        selectedChartID: Chart.ID? = nil,
        repository: ChartRepository? = nil
    ) {
        self.charts = charts
        self.entitlements = entitlements
        self.selectedChartID = Self.sanitizedSelection(selectedChartID, charts: charts)
        self.repository = repository
        persistenceEnabled = true
    }

    convenience init(snapshot: ChartLibrarySnapshot, repository: ChartRepository? = nil) {
        self.init(
            charts: snapshot.charts,
            entitlements: snapshot.entitlements,
            selectedChartID: snapshot.selectedChartID,
            repository: repository
        )
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
        var updatedEntitlements = entitlements
        updatedEntitlements.activePlan = plan
        entitlements = updatedEntitlements
    }

    @discardableResult
    func createBlankChart(in key: DocumentKey = .cMajor) -> Bool {
        guard canCreateChart else {
            return false
        }

        let newChart = Chart.draft(title: "Untitled Chart", key: key)
        charts.insert(newChart, at: 0)
        selectedChartID = newChart.id
        return true
    }

    var snapshot: ChartLibrarySnapshot {
        ChartLibrarySnapshot(
            charts: charts,
            selectedChartID: selectedChartID,
            entitlements: entitlements
        )
    }

    static func live(repository: ChartRepository = FileChartRepository.live()) -> ChartLibraryStore {
        let snapshot = (try? repository.loadSnapshot()) ?? .preview
        return ChartLibraryStore(snapshot: snapshot, repository: repository)
    }

    static var preview: ChartLibraryStore {
        ChartLibraryStore(snapshot: .preview)
    }

    private func persistIfNeeded() {
        guard persistenceEnabled, let repository else {
            return
        }

        do {
            try repository.saveSnapshot(snapshot)
        } catch {
            print("SmartChart persistence error: \(error)")
        }
    }

    private static func sanitizedSelection(_ selectedChartID: Chart.ID?, charts: [Chart]) -> Chart.ID? {
        if let selectedChartID,
           charts.contains(where: { $0.id == selectedChartID }) {
            return selectedChartID
        }

        return charts.first?.id
    }
}
