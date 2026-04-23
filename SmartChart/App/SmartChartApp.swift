import SwiftUI

@main
struct SmartChartApp: App {
    @StateObject private var store = ChartLibraryStore.live()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
        }
    }
}
