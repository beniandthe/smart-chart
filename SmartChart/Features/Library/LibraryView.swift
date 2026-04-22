import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: ChartLibraryStore

    var body: some View {
        List(selection: $store.selectedChartID) {
            Section("Plan") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.entitlements.activePlan.displayText)
                        .font(.headline)

                    Text(store.planSummaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.chartCapacityText)
                        .font(.subheadline.weight(.medium))

                    Text(store.upgradeSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Menu("Prototype Tier") {
                        ForEach(SmartChartPlan.allCases, id: \.self) { plan in
                            Button {
                                store.setPlan(plan)
                            } label: {
                                if store.entitlements.activePlan == plan {
                                    Label(plan.displayText, systemImage: "checkmark")
                                } else {
                                    Text(plan.displayText)
                                }
                            }
                        }
                    }
                    .font(.caption.weight(.semibold))

                    Text("Prototype only until StoreKit is wired.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            Section("Charts") {
                ForEach(store.charts) { chart in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chart.title)
                            .font(.headline)

                        Text("\(chart.documentKey.displayText) · \(chart.defaultMeter.displayText) · \(chart.measures.count) measures")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(chart.id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Menu {
                Section("Document Key") {
                    ForEach(DocumentKey.commonCreationKeys, id: \.self) { key in
                        Button(key.displayText) {
                            store.createBlankChart(in: key)
                        }
                    }
                }
            } label: {
                Label("New Chart", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canCreateChart)
            .padding()
            .background(.thinMaterial)
        }
    }
}
