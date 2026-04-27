import SwiftUI

@main
struct SmartChartApp: App {
    @StateObject private var store = ChartLibraryStore.live()

    init() {
        #if canImport(UIKit)
        NotationFontRegistrar.registerBundledFontsIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
        }
    }
}
