import SwiftUI

struct EditorView: View {
    private static let supportedTimeSignatureChoices = [
        Meter(numerator: 4, denominator: 4),
        Meter(numerator: 3, denominator: 4),
        Meter(numerator: 5, denominator: 4),
        Meter(numerator: 6, denominator: 4)
    ]

    @EnvironmentObject private var store: ChartLibraryStore
    @Binding var chart: Chart
    @State private var activeSheet: EditorSheet?
    @State private var exportAlertMessage = ""
    @State private var showingExportAlert = false
    @State private var showingSetupSheet = false
    @State private var showingHeaderSheet = false
    @State private var isExporting = false
    @State private var selectedMeasureID: UUID?
    @State private var pendingTimeSignatureSourceMeasureID: UUID?
    @State private var pendingTimeSignaturePlacement: PendingTimeSignaturePlacement?
    @State private var canvasMode: EditorCanvasMode = .browse
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
        .scrollDisabled(canvasMode.disablesPageScroll)
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
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    canvasMode = .browse
                    showingSetupSheet = true
                }
                .disabled(canvasMode.locksDocumentActions)

                Button {
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    canvasMode = .browse
                    handleExportTapped()
                } label: {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label(exportButtonTitle, systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || canvasMode.locksDocumentActions)
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
        .confirmationDialog(
            "Change Time Signature",
            isPresented: Binding(
                get: { pendingTimeSignatureSourceMeasureID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingTimeSignatureSourceMeasureID = nil
                    }
                }
            )
        ) {
            if let sourceMeasureID = pendingTimeSignatureSourceMeasureID {
                ForEach(Self.supportedTimeSignatureChoices, id: \.self) { meter in
                    Button(meter.displayText) {
                        pendingTimeSignatureSourceMeasureID = nil
                        pendingTimeSignaturePlacement = PendingTimeSignaturePlacement(
                            sourceMeasureID: sourceMeasureID,
                            meter: meter
                        )
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                pendingTimeSignatureSourceMeasureID = nil
                pendingTimeSignaturePlacement = nil
            }
        } message: {
            Text("Apply the new time signature after the selected measure.")
        }
        .sheet(item: $pendingTimeSignaturePlacement) { placement in
            TimeSignatureScopeSheetView(
                meter: placement.meter,
                onApplyCount: { additionalMeasureCount in
                    handleTimeSignatureSelection(
                        placement.meter,
                        after: placement.sourceMeasureID,
                        scope: .fixedMeasureCount(additionalMeasureCount)
                    )
                },
                onApplyToEndOfPiece: {
                    handleTimeSignatureSelection(
                        placement.meter,
                        after: placement.sourceMeasureID,
                        scope: .toEndOfPiece
                    )
                },
                onApplyToNextTimeSignature: {
                    handleTimeSignatureSelection(
                        placement.meter,
                        after: placement.sourceMeasureID,
                        scope: .toNextTimeSignature
                    )
                }
            )
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
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    canvasMode = .browse
                    showingSetupSheet = true
                } label: {
                    EditorMenuTabLabel(title: "Page", systemImage: "doc.text")
                }
                .buttonStyle(.plain)

                Button {
                    handleMeasureTabTapped()
                } label: {
                    EditorMenuTabLabel(
                        title: "Measures",
                        systemImage: "rectangle.split.4x1",
                        isSelected: canvasMode == .measureEdit
                    )
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Button {
                    handleTimeSignatureTabTapped()
                } label: {
                    EditorMenuTabLabel(
                        title: "Time",
                        systemImage: "metronome",
                        isSelected: canvasMode == .timeSignatureEdit
                    )
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Button {
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    toggleFreeHandMode()
                } label: {
                    EditorMenuTabLabel(
                        title: canvasMode.freeHandTabTitle,
                        systemImage: canvasMode.freeHandTabSymbol,
                        isSelected: canvasMode == .freeHand
                    )
                }
                .disabled(!canEnterFreeHandMode && canvasMode != .freeHand)
                .buttonStyle(.plain)

                EditorMenuTabLabel(title: "Jazz", systemImage: "music.quarternote.3", isSelected: true)

                Button {
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    canvasMode = .browse
                    showingHeaderSheet = true
                } label: {
                    EditorMenuTabLabel(title: "Header", systemImage: "character.cursor.ibeam")
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Menu {
                    ForEach(TranspositionView.allCases, id: \.self) { view in
                        Button {
                            selectedMeasureID = nil
                            pendingTimeSignatureSourceMeasureID = nil
                            pendingTimeSignaturePlacement = nil
                            canvasMode = .browse
                            chart.setTranspositionView(view)
                        } label: {
                            notationMenuLabel(view.displayText, isSelected: chart.defaultTranspositionView == view)
                        }
                    }
                } label: {
                    EditorMenuTabLabel(title: "View", systemImage: "guitars")
                }
                .disabled(canvasMode.locksDocumentActions)
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
            interactionMode: canvasMode,
            onTimeSignatureTargetRequested: handleTimeSignatureTargetRequested
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

        let targetMeasureID = resolvedMeasureActionTargetID()
        selectedMeasureID = nil
        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        canvasMode = .measureEdit

        guard let targetMeasureID else {
            _ = chart.appendMeasure(authoringState: .open)
            return
        }

        if chart.measure(id: targetMeasureID)?.authoringState == .open {
            _ = chart.commitOpenMeasure()
        } else {
            _ = chart.positionOpenMeasure(after: targetMeasureID)
        }
    }

    private func handleTimeSignatureTabTapped() {
        guard chart.hasCompletedInitialSetup else {
            showingSetupSheet = true
            return
        }

        selectedMeasureID = nil
        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        canvasMode = .timeSignatureEdit
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
        guard canEnterFreeHandMode || canvasMode == .freeHand else {
            if !chart.hasCompletedInitialSetup {
                showingSetupSheet = true
            }
            return
        }

        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        canvasMode = canvasMode == .freeHand ? .browse : .freeHand
    }

    private func handleTimeSignatureTargetRequested(_ measureID: UUID) {
        guard canvasMode == .timeSignatureEdit,
              chart.measure(id: measureID) != nil else {
            return
        }

        selectedMeasureID = measureID
        pendingTimeSignaturePlacement = nil
        pendingTimeSignatureSourceMeasureID = measureID
    }

    private func handleTimeSignatureSelection(
        _ meter: Meter,
        after sourceMeasureID: UUID,
        scope: TimeSignatureApplicationScope
    ) {
        let appliedMeasureID = chart.applyMeterChange(meter, after: sourceMeasureID, scope: scope)
        selectedMeasureID = sourceMeasureID
        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil

        if appliedMeasureID == nil {
            canvasMode = .browse
        }
    }

    private var canvasHeight: CGFloat {
        if !chart.hasCompletedInitialSetup {
            return 760
        }

        let visibleSystemCount = LeadSheetPageLayoutEngine.estimatedSystemCount(
            for: chart,
            pageWidth: 900
        )
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

private struct PendingTimeSignaturePlacement: Identifiable {
    let id = UUID()
    let sourceMeasureID: UUID
    let meter: Meter
}

private struct TimeSignatureScopeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let meter: Meter
    let onApplyCount: (Int) -> Void
    let onApplyToEndOfPiece: () -> Void
    let onApplyToNextTimeSignature: () -> Void

    @State private var additionalMeasureCount = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add measures of time?")
                        .font(.headline)
                    Text("The new \(meter.displayText) starts on the next measure.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $additionalMeasureCount, in: 0...32) {
                    HStack {
                        Text("Additional measures")
                        Spacer()
                        Text("\(additionalMeasureCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    onApplyCount(additionalMeasureCount)
                    dismiss()
                } label: {
                    Text("Apply Measure Count")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Or choose a span")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        bubbleButton(title: "To next time signature") {
                            onApplyToNextTimeSignature()
                            dismiss()
                        }

                        bubbleButton(title: "To end of piece") {
                            onApplyToEndOfPiece()
                            dismiss()
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Apply \(meter.displayText)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
    }

    @ViewBuilder
    private func bubbleButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.90, green: 0.95, blue: 1.0))
                .foregroundStyle(Color(red: 0.11, green: 0.31, blue: 0.64))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
