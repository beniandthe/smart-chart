import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: ChartLibraryStore
    @Binding var chart: Chart
    @State private var upgradeFeature: EntitledFeature?
    @State private var exportAlertMessage = ""
    @State private var showingExportAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                toolbarCard
                headerCard
                chartCanvas
                inspectorCard
            }
            .padding(24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $upgradeFeature) { feature in
            UpgradeSheetView(feature: feature)
                .environmentObject(store)
        }
        .alert("Export PDF", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportAlertMessage)
        }
    }

    private var toolbarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Toolbar")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(store.entitlements.activePlan.displayText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(planBadgeColor.opacity(0.14))
                    .clipShape(Capsule())

                Button {
                    handleExportTapped()
                } label: {
                    Label(exportButtonTitle, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    fontMenu
                    transposeMenu
                    notationMenu
                    textMenu
                }
                .padding(.vertical, 2)
            }

            Text(toolbarFootnote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Chart Title", text: $chart.title)
                .font(.largeTitle.weight(.semibold))
                .textFieldStyle(.plain)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Document Key")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(displayedDocumentKeySummary)
                        .font(chart.documentFont.metadataFont)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Meter")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Stepper(value: $chart.defaultMeter.numerator, in: 1...12) {
                            Text("\(chart.defaultMeter.numerator)")
                                .frame(minWidth: 24)
                        }

                        Text("/")
                            .foregroundStyle(.secondary)

                        Picker("Denominator", selection: $chart.defaultMeter.denominator) {
                            ForEach([2, 4, 8, 16], id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Transposition View")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(chart.defaultTranspositionView.displayText)
                        .font(chart.documentFont.metadataFont)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Prototype Focus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Timed chord events, meter, and clear one-page layout before handwriting recognition.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }

            HStack(spacing: 12) {
                Button {
                    chart.appendMeasure()
                } label: {
                    Label("Add Measure", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.borderedProminent)

                Text("\(chart.measures.count) total measures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chartCanvas: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Canvas")
                .font(.title2.weight(.semibold))

            ForEach($chart.systems) { $system in
                VStack(alignment: .leading, spacing: 12) {
                    let systemValue = system
                    let roadmapBadges = roadmapObjects(for: systemValue.id)
                    let labels = sectionLabels(for: systemValue.id)

                    if !roadmapBadges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(roadmapBadges) { roadmap in
                                    Text(roadmap.resolvedDisplayText)
                                        .font(chart.documentFont.sectionLabelFont)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.14))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if !labels.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(labels) { label in
                                Text(label.text.uppercased())
                                    .font(chart.documentFont.sectionLabelFont)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach($system.measures) { $measure in
                                MeasureCardView(
                                    measure: $measure,
                                    meter: measure.resolvedMeter(defaultMeter: chart.defaultMeter),
                                    cues: cues(for: measure.id),
                                    transpositionView: chart.defaultTranspositionView,
                                    fontPreset: chart.documentFont
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var inspectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector Placeholder")
                .font(.title3.weight(.semibold))

            Text("Next implementation pass: select a measure, chord, or notation badge, then edit beat position, duration, meter override, font overrides, and roadmap connections here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionLabels(for systemID: UUID) -> [SectionLabel] {
        chart.sectionLabels.filter { $0.anchorSystemID == systemID }
    }

    private func roadmapObjects(for systemID: UUID) -> [RoadmapObject] {
        chart.roadmapObjects.filter { $0.anchorSystemID == systemID }
    }

    private func cues(for measureID: UUID) -> [CueText] {
        chart.cueTexts.filter { $0.anchorMeasureID == measureID }
    }

    private var displayedDocumentKeySummary: String {
        let displayedKey = chart.documentKey.transposed(for: chart.defaultTranspositionView)
        return "\(displayedKey.displayText) · \(chart.defaultTranspositionView.displayText) view"
    }

    private var fontMenu: some View {
        Menu {
            Section("Document Font") {
                ForEach(ChartFontPreset.allCases, id: \.self) { preset in
                    Button {
                        handleFontSelection(preset)
                    } label: {
                        if chart.documentFont == preset {
                            Label(preset.displayText, systemImage: "checkmark")
                        } else if preset != .classic && !store.canUse(.fontPresets) {
                            Label(preset.displayText, systemImage: "lock.fill")
                        } else {
                            Text(preset.displayText)
                        }
                    }
                }
            }
        } label: {
            EditorMenuTabLabel(title: "Fonts", systemImage: "textformat")
        }
    }

    private var transposeMenu: some View {
        Menu {
            Section("Document Key") {
                ForEach(DocumentKey.commonCreationKeys, id: \.self) { key in
                    Button {
                        chart.setDocumentKey(key)
                    } label: {
                        if chart.documentKey == key {
                            Label(key.displayText, systemImage: "checkmark")
                        } else {
                            Text(key.displayText)
                        }
                    }
                }
            }

            Section("Display View") {
                ForEach(TranspositionView.allCases, id: \.self) { view in
                    Button {
                        handleTranspositionSelection(view)
                    } label: {
                        if chart.defaultTranspositionView == view {
                            Label(view.displayText, systemImage: "checkmark")
                        } else if view != .concert && !store.canUse(.documentTransposition) {
                            Label(view.displayText, systemImage: "lock.fill")
                        } else {
                            Text(view.displayText)
                        }
                    }
                }
            }
        } label: {
            EditorMenuTabLabel(title: "Transpose", systemImage: "music.note")
        }
    }

    private var notationMenu: some View {
        Menu {
            Section("Special Notation") {
                Button("Coda") { handleNotationSelection(.codaMarker) }
                Button("To Coda") { handleNotationSelection(.toCoda) }
                Button("Segno") { handleNotationSelection(.segno) }
                Button("D.S. al Coda") { handleNotationSelection(.dsAlCoda) }
                Button("D.C. al Fine") { handleNotationSelection(.dcAlFine) }
                Button("Fine") { handleNotationSelection(.fine) }
                Button("1st Ending") { handleNotationSelection(.ending1) }
                Button("2nd Ending") { handleNotationSelection(.ending2) }
            }
        } label: {
            EditorMenuTabLabel(title: "Notation", systemImage: "flag")
        }
    }

    private var textMenu: some View {
        Menu {
            Section("Section Labels") {
                Button("Intro") { chart.addSectionLabel(text: "Intro") }
                Button("Verse") { chart.addSectionLabel(text: "Verse") }
                Button("Chorus") { chart.addSectionLabel(text: "Chorus") }
                Button("Bridge") { chart.addSectionLabel(text: "Bridge") }
            }

            Section("Cue Text") {
                Button("hits") { chart.addCueText("hits") }
                Button("stop time") { chart.addCueText("stop time") }
                Button("tacet") { chart.addCueText("tacet") }
            }
        } label: {
            EditorMenuTabLabel(title: "Text", systemImage: "character.textbox")
        }
    }

    private var exportButtonTitle: String {
        store.canUse(.pdfExport) ? "Export PDF" : "Export PDF (Pro)"
    }

    private var toolbarFootnote: String {
        if store.entitlements.activePlan == .free {
            return "Text tools and core chart editing stay available in Free. Font presets, transposed views, special notation tools, and PDF export unlock with Pro."
        }

        return "Pro tools are unlocked in this prototype. Selection-aware font edits and draggable snapping come in the next interactive pass."
    }

    private var planBadgeColor: Color {
        switch store.entitlements.activePlan {
        case .free:
            return .orange
        case .proLifetime:
            return .blue
        case .studioSubscription:
            return .green
        }
    }

    private func handleFontSelection(_ preset: ChartFontPreset) {
        guard preset != .classic else {
            chart.setDocumentFont(preset)
            return
        }

        performOrPromptUpgrade(for: .fontPresets) {
            chart.setDocumentFont(preset)
        }
    }

    private func handleTranspositionSelection(_ view: TranspositionView) {
        guard view == .concert || store.canUse(.documentTransposition) else {
            promptUpgrade(for: .documentTransposition)
            return
        }

        chart.setTranspositionView(view)
    }

    private func handleNotationSelection(_ type: RoadmapType) {
        performOrPromptUpgrade(for: .roadmapNotationTools) {
            chart.addRoadmapObject(type)
        }
    }

    private func handleExportTapped() {
        guard store.canUse(.pdfExport) else {
            promptUpgrade(for: .pdfExport)
            return
        }

        exportAlertMessage = "PDF export is unlocked on this plan, but the actual render and share flow is still a prototype placeholder."
        showingExportAlert = true
    }

    private func performOrPromptUpgrade(for feature: EntitledFeature, action: () -> Void) {
        if store.canUse(feature) {
            action()
        } else {
            promptUpgrade(for: feature)
        }
    }

    private func promptUpgrade(for feature: EntitledFeature) {
        upgradeFeature = feature
    }
}
