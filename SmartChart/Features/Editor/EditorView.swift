import Foundation
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
    @State private var showingRhythmicNotationAcceptanceSheet = false
    @State private var activeAppearancePanel: ChartAppearancePanel?
    @State private var hasPresentedRhythmicNotationGuide = false
    @State private var isExporting = false
    @State private var rhythmicNotationErrorMessage = ""
    @State private var showingRhythmicNotationError = false
    @State private var pendingRhythmicNotationConfirmation: PendingRhythmicNotationConfirmation?
    @State private var selectedMeasureID: UUID?
    @State private var pendingTimeSignatureSourceMeasureID: UUID?
    @State private var pendingTimeSignaturePlacement: PendingTimeSignaturePlacement?
    @State private var freeHandReturnMode: EditorCanvasMode = .browse
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
                    freeHandReturnMode = .browse
                    canvasMode = .browse
                    showingSetupSheet = true
                }
                .disabled(canvasMode.locksDocumentActions)

                Button {
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    freeHandReturnMode = .browse
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
        .sheet(item: $activeAppearancePanel) { panel in
            ChartAppearanceSheetView(chart: $chart, panel: panel)
        }
        .sheet(isPresented: $showingRhythmicNotationAcceptanceSheet) {
            RhythmicNotationAcceptanceSheetView()
        }
        .sheet(item: $pendingRhythmicNotationConfirmation) { confirmation in
            RhythmicNotationConfirmationSheetView(
                confirmation: confirmation,
                onAccept: {
                    handleRhythmicNotationConfirmationAccepted(confirmation)
                },
                onRewrite: {
                    handleRhythmicNotationConfirmationRewriteRequested(confirmation)
                }
            )
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
        .alert("Rhythmic Notation", isPresented: $showingRhythmicNotationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rhythmicNotationErrorMessage)
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
                    freeHandReturnMode = .browse
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
                    handleRhythmicNotationTabTapped()
                } label: {
                    EditorMenuTabLabel(
                        title: "Rhythmic Notation",
                        systemImage: "note.quarter",
                        isSelected: canvasMode == .rhythmicNotationEdit
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
                .disabled(!chart.hasCompletedInitialSetup && canvasMode != .freeHand)
                .buttonStyle(.plain)

                EditorMenuTabLabel(title: "Jazz", systemImage: "music.quarternote.3", isSelected: true)

                Button {
                    presentAppearancePanel(.documentStyle)
                } label: {
                    EditorMenuTabLabel(
                        title: "Style",
                        systemImage: "paintpalette",
                        isSelected: activeAppearancePanel == .documentStyle
                    )
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Button {
                    presentAppearancePanel(.notationFont)
                } label: {
                    EditorMenuTabLabel(
                        title: "Fonts",
                        systemImage: "textformat",
                        isSelected: activeAppearancePanel == .notationFont
                    )
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Button {
                    presentAppearancePanel(.engraving)
                } label: {
                    EditorMenuTabLabel(
                        title: "Engraving",
                        systemImage: "slider.horizontal.3",
                        isSelected: activeAppearancePanel == .engraving
                    )
                }
                .disabled(canvasMode.locksDocumentActions)
                .buttonStyle(.plain)

                Button {
                    selectedMeasureID = nil
                    pendingTimeSignatureSourceMeasureID = nil
                    pendingTimeSignaturePlacement = nil
                    freeHandReturnMode = .browse
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
                            freeHandReturnMode = .browse
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
            onTimeSignatureTargetRequested: handleTimeSignatureTargetRequested,
            onRhythmicNotationProposal: handleRhythmicNotationProposal,
            onRhythmicNotationValidationError: handleRhythmicNotationValidationError
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
        freeHandReturnMode = .browse
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

        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        freeHandReturnMode = .browse
        canvasMode = .timeSignatureEdit
    }

    private func handleRhythmicNotationTabTapped() {
        guard chart.hasCompletedInitialSetup else {
            showingSetupSheet = true
            return
        }

        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        freeHandReturnMode = .browse

        if canvasMode == .rhythmicNotationEdit {
            showingRhythmicNotationAcceptanceSheet = true
            return
        }

        canvasMode = .rhythmicNotationEdit

        if !hasPresentedRhythmicNotationGuide {
            showingRhythmicNotationAcceptanceSheet = true
            hasPresentedRhythmicNotationGuide = true
        }
    }

    private func presentAppearancePanel(_ panel: ChartAppearancePanel) {
        selectedMeasureID = nil
        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        freeHandReturnMode = .browse
        canvasMode = .browse
        activeAppearancePanel = panel
    }

    private func resolvedMeasureActionTargetID() -> UUID? {
        if let selectedMeasureID,
           chart.measure(id: selectedMeasureID) != nil {
            return selectedMeasureID
        }

        return chart.measures.first(where: { $0.authoringState == .open })?.id
            ?? chart.measures.last?.id
    }

    private func toggleFreeHandMode() {
        if canvasMode == .freeHand {
            pendingTimeSignatureSourceMeasureID = nil
            pendingTimeSignaturePlacement = nil
            canvasMode = freeHandReturnMode
            return
        }

        guard chart.hasCompletedInitialSetup else {
            if !chart.hasCompletedInitialSetup {
                showingSetupSheet = true
            }
            return
        }

        pendingTimeSignatureSourceMeasureID = nil
        pendingTimeSignaturePlacement = nil
        freeHandReturnMode = canvasMode
        canvasMode = .freeHand
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

    private func handleRhythmicNotationValidationError(_ message: String) {
        rhythmicNotationErrorMessage = message
        showingRhythmicNotationError = true
        canvasMode = .rhythmicNotationEdit
    }

    private func handleRhythmicNotationProposal(
        measureID: UUID,
        values: [RhythmValue],
        drawingData: Data
    ) {
        guard let measure = chart.measure(id: measureID) else {
            return
        }

        selectedMeasureID = measureID
        canvasMode = .rhythmicNotationEdit
        pendingRhythmicNotationConfirmation = PendingRhythmicNotationConfirmation(
            measureID: measureID,
            measureIndex: measure.index,
            meter: measure.resolvedMeter(defaultMeter: chart.defaultMeter),
            values: values,
            drawingData: drawingData
        )
    }

    private func handleRhythmicNotationConfirmationAccepted(
        _ confirmation: PendingRhythmicNotationConfirmation
    ) {
        var updatedChart = chart
        _ = updatedChart.setMeasureRhythmMap(
            confirmation.values,
            drawingData: confirmation.drawingData,
            for: confirmation.measureID
        )
        _ = updatedChart.clearMeasureRhythmicNotation(
            for: confirmation.measureID,
            clearRhythmMap: false
        )

        chart = updatedChart
        selectedMeasureID = confirmation.measureID
        canvasMode = .rhythmicNotationEdit
        pendingRhythmicNotationConfirmation = nil
    }

    private func handleRhythmicNotationConfirmationRewriteRequested(
        _ confirmation: PendingRhythmicNotationConfirmation
    ) {
        var updatedChart = chart
        _ = updatedChart.clearMeasureRhythmicNotation(
            for: confirmation.measureID,
            clearRhythmMap: true
        )

        chart = updatedChart
        selectedMeasureID = confirmation.measureID
        canvasMode = .rhythmicNotationEdit
        pendingRhythmicNotationConfirmation = nil
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

private struct PendingRhythmicNotationConfirmation: Identifiable {
    let id = UUID()
    let measureID: UUID
    let measureIndex: Int
    let meter: Meter
    let values: [RhythmValue]
    let drawingData: Data

    var displayMeasureNumber: Int {
        measureIndex + 1
    }

    var requiredBeatCount: Double {
        meter.measureLengthInWholeNotes / meter.beatUnitWholeNoteLength
    }

    var recognizedBeatCount: Double {
        values.reduce(0) { partialResult, value in
            partialResult + value.wholeNoteLength / meter.beatUnitWholeNoteLength
        }
    }
}

private struct RhythmicNotationConfirmationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let confirmation: PendingRhythmicNotationConfirmation
    let onAccept: () -> Void
    let onRewrite: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Measure \(confirmation.displayMeasureNumber)")
                        .font(.title3.weight(.semibold))
                    Text("The app read your handwriting as this rhythm. Accept it if it is right, or keep editing the ink in the measure.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Read as")
                            .font(.headline)
                        Spacer()
                        Text("\(formattedBeats(confirmation.recognizedBeatCount)) / \(formattedBeats(confirmation.requiredBeatCount)) beats")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    FlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(Array(confirmation.values.enumerated()), id: \.offset) { _, value in
                            Text(value.debugConfirmationLabel)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(value.isRest ? Color.orange.opacity(0.15) : Color.blue.opacity(0.13))
                                .foregroundStyle(value.isRest ? Color.orange : Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 10) {
                    Button {
                        onAccept()
                        dismiss()
                    } label: {
                        Text("Use This Rhythm")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        onRewrite()
                        dismiss()
                    } label: {
                        Text("Clear Measure & Rewrite")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Confirm Rhythm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep Editing") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(420), .medium])
    }

    private func formattedBeats(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }

        return String(format: "%.1f", value)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = layout(in: bounds.width, subviews: subviews).rows
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func layout(in availableWidth: CGFloat, subviews: Subviews) -> FlowLayoutResult {
        let safeWidth = max(1, availableWidth)
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > safeWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, height: currentHeight, width: currentWidth))
                currentItems = [FlowItem(subview: subview, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(subview: subview, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, height: currentHeight, width: currentWidth))
        }

        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + max(0, CGFloat(rows.count - 1)) * rowSpacing
        let width = rows.reduce(CGFloat.zero) { partialResult, row in
            max(partialResult, row.width)
        }

        return FlowLayoutResult(size: CGSize(width: width, height: height), rows: rows)
    }
}

private struct FlowLayoutResult {
    let size: CGSize
    let rows: [FlowRow]
}

private struct FlowRow {
    let items: [FlowItem]
    let height: CGFloat
    let width: CGFloat
}

private struct FlowItem {
    let subview: LayoutSubview
    let size: CGSize
}

private extension RhythmValue {
    var debugConfirmationLabel: String {
        switch self {
        case .eighth:
            return "eighth"
        case .eighthRest:
            return "eighth rest"
        case .quarter:
            return "quarter"
        case .quarterRest:
            return "quarter rest"
        case .dottedQuarter:
            return "dotted quarter"
        case .half:
            return "half"
        case .halfRest:
            return "half rest"
        case .dottedHalf:
            return "dotted half"
        case .whole:
            return "whole"
        case .wholeRest:
            return "whole rest"
        case .tiedContinuation:
            return "tie"
        }
    }
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
