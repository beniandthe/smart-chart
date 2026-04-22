import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: ChartLibraryStore

    var body: some View {
        NavigationSplitView {
            LibraryView()
                .navigationTitle("Smart Chart")
        } detail: {
            if let chart = selectedChartBinding {
                EditorView(chart: chart)
            } else {
                ContentUnavailableView(
                    "No Chart Selected",
                    systemImage: "music.quarternote.3",
                    description: Text("Create a chart to start mapping chords, rhythm, and roadmap flow.")
                )
            }
        }
    }

    private var selectedChartBinding: Binding<Chart>? {
        guard let selectedChartID = store.selectedChartID,
              let index = store.charts.firstIndex(where: { $0.id == selectedChartID }) else {
            return nil
        }

        return $store.charts[index]
    }
}
