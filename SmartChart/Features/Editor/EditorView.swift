import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: ChartLibraryStore
    @Binding var chart: Chart
    @State private var activeSheet: EditorSheet?
    @State private var exportAlertMessage = ""
    @State private var showingExportAlert = false
    @State private var showingSetupSheet = false
    @State private var showingHeaderSheet = false
    @State private var isExporting = false
    @State private var selectedMeasureID: UUID?
    @State private var isFreeHandMode = false
    private let exporter: any ChartExporting

    init(chart: Binding<Chart>, exporter: any ChartExporting = PDFChartExporter.live()) {
        self._chart = chart
        self.exporter = exporter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                toolStrip

                canvasView
                    .frame(minHeight: canvasHeight)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .scrollDisabled(isFreeHandMode)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.94, blue: 0.91),
                    Color(red: 0.90, green: 0.93, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle(chart.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(chart.hasCompletedInitialSetup ? "Page Setup" : "Setup") {
                    showingSetupSheet = true
                }
                .disabled(isFreeHandMode)

                Button {
                    handleExportTapped()
                } label: {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label(exportButtonTitle, systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || isFreeHandMode)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .upgrade(let feature):
                UpgradeSheetView(feature: feature)
                    .environmentObject(store)
            case .export(let exportedPDF):
                PDFExportPreviewView(exportedPDF: exportedPDF)
            }
        }
        .sheet(isPresented: $showingSetupSheet) {
            ChartSetupSheetView(chart: $chart)
        }
        .sheet(isPresented: $showingHeaderSheet) {
            ChartHeaderSheetView(chart: $chart)
        }
        .alert("Export PDF", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportAlertMessage)
        }
        .task {
            if chart.staffStyle != .fiveLine {
                chart.staffStyle = .fiveLine
                chart.updatedAt = .now
            }
            if !chart.hasCompletedInitialSetup {
                showingSetupSheet = true
            }
        }
    }

    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    showingSetupSheet = true
                } label: {
                    EditorMenuTabLabel(title: "Page", systemImage: "doc.text")
                }
                .buttonStyle(.plain)

                Button {
                    handleMeasureTabTapped()
                } label: {
                    EditorMenuTabLabel(title: "Measures", systemImage: "rectangle.split.4x1")
                }
                .disabled(isFreeHandMode)
                .buttonStyle(.plain)

                Button {
                    toggleFreeHandMode()
                } label: {
                    EditorMenuTabLabel(
                        title: isFreeHandMode ? "Done" : "Free-Hand",
                        systemImage: isFreeHandMode ? "pencil.slash" : "pencil.and.scribble",
                        isSelected: isFreeHandMode
                    )
                }
                .disabled(!canEnterFreeHandMode && !isFreeHandMode)
                .buttonStyle(.plain)

                EditorMenuTabLabel(title: "Jazz", systemImage: "music.quarternote.3", isSelected: true)

                Button {
                    showingHeaderSheet = true
                } label: {
                    EditorMenuTabLabel(title: "Header", systemImage: "character.cursor.ibeam")
                }
                .disabled(isFreeHandMode)
                .buttonStyle(.plain)

                Menu {
                    ForEach(TranspositionView.allCases, id: \.self) { view in
                        Button {
                            chart.setTranspositionView(view)
                        } label: {
                            notationMenuLabel(view.displayText, isSelected: chart.defaultTranspositionView == view)
                        }
                    }
                } label: {
                    EditorMenuTabLabel(title: "View", systemImage: "guitars")
                }
                .disabled(isFreeHandMode)
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.white.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var canvasView: some View {
        LeadSheetCanvasHostView(
            chart: $chart,
            selectedMeasureID: $selectedMeasureID,
            isFreeHandMode: isFreeHandMode
        )
    }

    private var exportButtonTitle: String {
        store.canUse(.pdfExport) ? "Export PDF" : "Export PDF (Pro)"
    }

    private func handleExportTapped() {
        guard store.canUse(.pdfExport) else {
            activeSheet = .upgrade(.pdfExport)
            return
        }

        let chartToExport = chart
        isExporting = true

        Task {
            do {
                let exportedURL = try await exporter.exportPDF(for: chartToExport)
                await MainActor.run {
                    activeSheet = .export(
                        ExportedPDF(
                            url: exportedURL,
                            chartTitle: chartToExport.title
                        )
                    )
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportAlertMessage = "Couldn’t generate the PDF right now. \(error.localizedDescription)"
                    showingExportAlert = true
                    isExporting = false
                }
            }
        }
    }

    private func handleMeasureTabTapped() {
        guard chart.hasCompletedInitialSetup else {
            showingSetupSheet = true
            return
        }

        guard let targetMeasureID = resolvedMeasureActionTargetID() else {
            selectedMeasureID = chart.appendMeasure(authoringState: .open)
            return
        }

        if chart.measure(id: targetMeasureID)?.authoringState == .open {
            selectedMeasureID = chart.commitOpenMeasure()
        } else {
            selectedMeasureID = chart.positionOpenMeasure(after: targetMeasureID) ?? targetMeasureID
        }
    }

    private func resolvedMeasureActionTargetID() -> UUID? {
        if let selectedMeasureID,
           chart.measure(id: selectedMeasureID) != nil {
            return selectedMeasureID
        }

        return chart.measures.first(where: { $0.authoringState == .open })?.id
            ?? chart.measures.last?.id
    }

    private var canEnterFreeHandMode: Bool {
        chart.hasCompletedInitialSetup
    }

    private func toggleFreeHandMode() {
        guard canEnterFreeHandMode || isFreeHandMode else {
            if !chart.hasCompletedInitialSetup {
                showingSetupSheet = true
            }
            return
        }

        if !isFreeHandMode {
            selectedMeasureID = resolvedMeasureActionTargetID()
        }

        isFreeHandMode.toggle()
    }

    private var canvasHeight: CGFloat {
        if !chart.hasCompletedInitialSetup {
            return 760
        }

        let visibleSystemCount = max(1, chart.systems.count)
        return max(1200, CGFloat(visibleSystemCount) * 136 + 320)
    }

    @ViewBuilder
    private func notationMenuLabel(_ title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

private enum EditorSheet: Identifiable {
    case upgrade(EntitledFeature)
    case export(ExportedPDF)

    var id: String {
        switch self {
        case .upgrade(let feature):
            return "upgrade-\(feature.id)"
        case .export(let exportedPDF):
            return "export-\(exportedPDF.id.absoluteString)"
        }
    }
}
