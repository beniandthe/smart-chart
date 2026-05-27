import SwiftUI

struct PendingChordInkConfirmation: Identifiable {
    let id = UUID()
    let measureID: UUID
    let measureIndex: Int
    let result: ChordInkRecognitionResult
    let drawingData: Data
    let targetFraction: Double?
    let recognitionTiming: ChordInkRecognitionTiming?
    let proposalDecisionMilliseconds: Double?
    let primaryDecision: ChordInkRecognitionDecision
    let decision: ChordInkRecognitionDecision
    let candidateTexts: [String]
    let bestCandidateText: String?

    init(
        measureID: UUID,
        measureIndex: Int,
        result: ChordInkRecognitionResult,
        drawingData: Data,
        targetFraction: Double?,
        recognitionTiming: ChordInkRecognitionTiming? = nil,
        proposalDecisionMilliseconds: Double? = nil,
        primaryDecision: ChordInkRecognitionDecision,
        decision: ChordInkRecognitionDecision
    ) {
        self.measureID = measureID
        self.measureIndex = measureIndex
        self.result = result
        self.drawingData = drawingData
        self.targetFraction = targetFraction
        self.recognitionTiming = recognitionTiming
        self.proposalDecisionMilliseconds = proposalDecisionMilliseconds
        self.primaryDecision = primaryDecision
        self.decision = decision

        let rankedCandidateTexts = ChordInkRecognitionPolicy.rankedSupportedScores(for: result)
            .compactMap(\.displayText)
        let primaryCandidateTexts = [result.match?.displayText].compactMap { $0 }
        let ocrCandidateTexts = result.ocrCandidates?.compactMap(\.displayText) ?? []
        let userFacingCandidateTexts = ChordRecognitionCompendium.userFacingCandidateTexts(
            from: rankedCandidateTexts + primaryCandidateTexts + result.rawCandidates + ocrCandidateTexts
        )
        self.candidateTexts = userFacingCandidateTexts
        self.bestCandidateText = result.match?.displayText ?? userFacingCandidateTexts.first
    }

    var displayMeasureNumber: Int {
        measureIndex + 1
    }

    var requiresDirectEntry: Bool {
        candidateTexts.isEmpty && result.match == nil && decision.acceptedText == nil
    }

    var visibleCandidateTexts: [String] {
        Array(candidateTexts.prefix(3))
    }
}

struct PendingChordCorrection: Identifiable {
    let id = UUID()
    let chordEventID: UUID
    let measureID: UUID
    let measureIndex: Int
    let currentText: String
    let rawInput: String?

    var displayMeasureNumber: Int {
        measureIndex + 1
    }

    var candidateTexts: [String] {
        var texts = [currentText]
        if let rawInput {
            texts.append(rawInput)
        }

        return texts.reduce(into: [String]()) { result, text in
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty,
                  !result.contains(trimmedText) else {
                return
            }

            result.append(trimmedText)
        }
    }
}

enum ChordInkFixtureCopyResult: Equatable {
    case copied(displayText: String, fixtureName: String)
    case failed(String)

    var message: String {
        switch self {
        case .copied(let displayText, let fixtureName):
            "Copied \(displayText) regression fixture as \(fixtureName). Watcher will import it."
        case .failed(let message):
            message
        }
    }

    var isFailure: Bool {
        switch self {
        case .copied:
            false
        case .failed:
            true
        }
    }
}

struct ChordInkConfirmationSheetView: View {
    let confirmation: PendingChordInkConfirmation
    let showsFixtureCaptureTools: Bool
    let onAcceptCandidate: (String) -> Void
    let onCopyFixtureJSON: (String) -> ChordInkFixtureCopyResult
    let onKeepInk: () -> Void
    let onClearAndRewrite: () -> Void
    @State private var manualCandidateText: String
    @State private var fixtureCopyStatus: ChordInkFixtureCopyResult?
    @FocusState private var isManualEntryFocused: Bool

    init(
        confirmation: PendingChordInkConfirmation,
        showsFixtureCaptureTools: Bool = false,
        onAcceptCandidate: @escaping (String) -> Void,
        onCopyFixtureJSON: @escaping (String) -> ChordInkFixtureCopyResult,
        onKeepInk: @escaping () -> Void,
        onClearAndRewrite: @escaping () -> Void
    ) {
        self.confirmation = confirmation
        self.showsFixtureCaptureTools = showsFixtureCaptureTools
        self.onAcceptCandidate = onAcceptCandidate
        self.onCopyFixtureJSON = onCopyFixtureJSON
        self.onKeepInk = onKeepInk
        self.onClearAndRewrite = onClearAndRewrite
        _manualCandidateText = State(initialValue: confirmation.bestCandidateText ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    candidateChips
                    manualEntry
                    chartActions
                    if showsFixtureCaptureTools {
                        captureActions
                    }
                }
                .padding(22)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(confirmation.requiresDirectEntry ? "Enter Chord" : "Choose Chord")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(true)
        .task(id: confirmation.id) {
            guard confirmation.requiresDirectEntry else {
                return
            }

            isManualEntryFocused = true
        }
    }

    private var trimmedCandidateText: String {
        manualCandidateText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var statusTitle: String {
        if confirmation.requiresDirectEntry {
            return "Needs a chord"
        }

        if confirmation.decision.reason.localizedCaseInsensitiveContains("previously rendered") {
            return "Try a different read"
        }

        if confirmation.decision.isCloseRace {
            return "Close read"
        }

        return "Confirm the read"
    }

    private var statusMessage: String {
        if confirmation.requiresDirectEntry {
            return "Type the chord you meant and keep moving."
        }

        if confirmation.decision.reason.localizedCaseInsensitiveContains("previously rendered") {
            return "That result was deleted once, so it will not auto-render again without your say."
        }

        if confirmation.decision.isCloseRace {
            return "Two reads are close. Pick the one that belongs on the chart."
        }

        return "This read needs one quick check before it becomes chart text."
    }

    private var statusIconName: String {
        if confirmation.requiresDirectEntry {
            return "keyboard"
        }

        if confirmation.decision.reason.localizedCaseInsensitiveContains("previously rendered") {
            return "arrow.triangle.2.circlepath"
        }

        if confirmation.decision.isCloseRace {
            return "questionmark.circle.fill"
        }

        return "checkmark.circle.fill"
    }

    private var statusTint: Color {
        if confirmation.requiresDirectEntry {
            return .orange
        }

        if confirmation.decision.reason.localizedCaseInsensitiveContains("previously rendered") {
            return .purple
        }

        if confirmation.decision.isCloseRace {
            return .blue
        }

        return .green
    }

    private var primaryActionTitle: String {
        trimmedCandidateText.isEmpty ? "Use Chord" : "Use \(trimmedCandidateText)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 34, height: 34)
                    .background(statusTint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.title3.weight(.semibold))

                    Text("Measure \(confirmation.displayMeasureNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(trimmedCandidateText.isEmpty ? "Type chord" : trimmedCandidateText)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                Spacer(minLength: 12)

                if let match = confirmation.result.match {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Best read")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(match.displayText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                } else {
                    Image(systemName: "text.cursor")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusTint.opacity(0.18), lineWidth: 1)
        }
    }

    private var candidateChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Suggestions", systemImage: "list.number")
                    .font(.headline.weight(.semibold))

                Spacer()

                if !confirmation.visibleCandidateTexts.isEmpty {
                    Text("Top \(confirmation.visibleCandidateTexts.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            let candidates = confirmation.visibleCandidateTexts
            if candidates.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.and.scribble")
                        .foregroundStyle(.orange)

                    Text("No useful suggestions this time.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(candidates.enumerated()), id: \.element) { index, candidate in
                        Button {
                            manualCandidateText = candidate
                            fixtureCopyStatus = nil
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(candidate == trimmedCandidateText ? Color.white : Color.secondary)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(candidate == trimmedCandidateText ? Color.blue : Color(uiColor: .tertiarySystemFill))
                                    )

                                Text(candidate)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)

                                Spacer(minLength: 8)

                                if candidate == trimmedCandidateText {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(candidate == trimmedCandidateText ? Color.blue.opacity(0.11) : Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(candidate == trimmedCandidateText ? Color.blue.opacity(0.42) : Color.black.opacity(0.06), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Suggestion \(index + 1), \(candidate)")
                    }
                }
            }
        }
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Type instead", systemImage: "keyboard")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    isManualEntryFocused = true
                } label: {
                    Image(systemName: "cursorarrow.rays")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Focus chord entry")
            }

            HStack(spacing: 10) {
                TextField("C, Bb, Db7(b9), G/B", text: $manualCandidateText)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isManualEntryFocused)
                    .submitLabel(.done)
                    .animation(nil, value: manualCandidateText)
                    .onSubmit {
                        acceptTrimmedCandidate()
                    }
                    .onChange(of: manualCandidateText) { _, _ in
                        if fixtureCopyStatus != nil {
                            fixtureCopyStatus = nil
                        }
                    }

                Image(systemName: "return")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isManualEntryFocused ? Color.blue.opacity(0.45) : Color.black.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var captureActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fixture capture")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                fixtureCopyStatus = onCopyFixtureJSON(trimmedCandidateText)
            } label: {
                Text("Copy Regression Fixture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedCandidateText.isEmpty)

            if let fixtureCopyStatus {
                Text(fixtureCopyStatus.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(fixtureCopyStatus.isFailure ? Color.red : Color.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(role: .destructive) {
                onClearAndRewrite()
            } label: {
                Text("Clear Ink")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var chartActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                acceptTrimmedCandidate()
            } label: {
                Label(primaryActionTitle, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedCandidateText.isEmpty)

            HStack(spacing: 10) {
                Button {
                    onKeepInk()
                } label: {
                    Label("Keep Ink", systemImage: "pencil.tip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    onClearAndRewrite()
                } label: {
                    Label("Rewrite", systemImage: "eraser")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func acceptTrimmedCandidate() {
        guard !trimmedCandidateText.isEmpty else {
            return
        }

        onAcceptCandidate(trimmedCandidateText)
    }
}

struct ChordCorrectionSheetView: View {
    let correction: PendingChordCorrection
    let onAcceptCandidate: (String) -> Void
    let onCancel: () -> Void
    @State private var candidateText: String
    @FocusState private var isCandidateFocused: Bool

    init(
        correction: PendingChordCorrection,
        onAcceptCandidate: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.correction = correction
        self.onAcceptCandidate = onAcceptCandidate
        self.onCancel = onCancel
        _candidateText = State(initialValue: correction.rawInput ?? correction.currentText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    correctionHeader
                    correctionCandidates
                    correctionEntry
                    correctionActions
                }
                .padding(22)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Correct Chord")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .task {
            isCandidateFocused = true
        }
    }

    private var correctionHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Update the chord")
                        .font(.title3.weight(.semibold))

                    Text("Measure \(correction.displayMeasureNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Text("Make this rendered chord match the chart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(correction.currentText)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 5) {
                    Text("New")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(trimmedCandidateText.isEmpty ? "Type chord" : trimmedCandidateText)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        }
    }

    private var correctionCandidates: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quick choices", systemImage: "list.bullet")
                .font(.headline.weight(.semibold))

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(correction.candidateTexts, id: \.self) { candidate in
                    Button {
                        candidateText = candidate
                    } label: {
                        HStack(spacing: 6) {
                            Text(candidate)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            if candidate == trimmedCandidateText {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(candidate == trimmedCandidateText ? Color.blue.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(candidate == trimmedCandidateText ? Color.blue : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var correctionEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Chord", systemImage: "keyboard")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    isCandidateFocused = true
                } label: {
                    Image(systemName: "cursorarrow.rays")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Focus chord entry")
            }

            HStack(spacing: 10) {
                TextField("C, Bb, Db7(b9), G/B", text: $candidateText)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isCandidateFocused)
                    .submitLabel(.done)
                    .animation(nil, value: candidateText)
                    .onSubmit {
                        acceptTrimmedCandidate()
                    }

                Image(systemName: "return")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isCandidateFocused ? Color.blue.opacity(0.45) : Color.black.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var correctionActions: some View {
        VStack(spacing: 10) {
            Button {
                acceptTrimmedCandidate()
            } label: {
                Label(trimmedCandidateText.isEmpty ? "Update Chord" : "Update to \(trimmedCandidateText)", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmedCandidateText.isEmpty)

            Button {
                onCancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var trimmedCandidateText: String {
        candidateText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func acceptTrimmedCandidate() {
        guard !trimmedCandidateText.isEmpty else {
            return
        }

        onAcceptCandidate(trimmedCandidateText)
    }
}
