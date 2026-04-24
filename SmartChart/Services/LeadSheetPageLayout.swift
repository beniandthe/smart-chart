import CoreGraphics
import Foundation

struct LeadSheetPageLayout: Hashable {
    var pageBounds: CGRect
    var paperFrame: CGRect
    var header: LeadSheetHeaderLayout
    var systems: [LeadSheetSystemLayout]
}

struct LeadSheetHeaderLayout: Hashable {
    var frame: CGRect
    var titleFrame: CGRect
    var composerFrame: CGRect?
    var styleNoteFrame: CGRect?
    var keyFrame: CGRect
    var meterFrame: CGRect
}

struct LeadSheetSystemLayout: Identifiable, Hashable {
    var id: UUID
    var index: Int
    var frame: CGRect
    var staffLineYPositions: [CGFloat]
    var clefFrame: CGRect?
    var timeSignatureFrame: CGRect?
    var sectionTextFrame: CGRect?
    var sectionText: String?
    var roadmapTextFrame: CGRect?
    var roadmapText: String?
    var measures: [LeadSheetMeasureLayout]
}

struct LeadSheetMeasureLayout: Identifiable, Hashable {
    var id: UUID
    var sourceMeasureID: UUID?
    var index: Int
    var frame: CGRect
    var staffFrame: CGRect
    var chordBandFrame: CGRect
    var writableFrame: CGRect
    var chordLayouts: [LeadSheetChordLayout]
    var noteLayouts: [LeadSheetNoteLayout]
    var barlineAfter: BarlineType
    var trailingMeterChange: Meter?
    var trailingMeterChangeFrame: CGRect?
    var trailingBarlineFrame: CGRect
    var isOpen: Bool
}

struct LeadSheetChordLayout: Identifiable, Hashable {
    var id: UUID
    var text: String
    var frame: CGRect
}

struct LeadSheetNoteLayout: Identifiable, Hashable {
    enum HeadStyle: Hashable {
        case whole
        case half
        case filled
    }

    enum FlagStyle: Hashable {
        case none
        case single
    }

    var id: UUID
    var noteheadFrame: CGRect
    var headStyle: HeadStyle
    var stemStart: CGPoint?
    var stemEnd: CGPoint?
    var stemGoesUp: Bool
    var flagStyle: FlagStyle
    var dotFrame: CGRect?
    var tieFrame: CGRect?
}

enum LeadSheetPageLayoutEngine {
    private static let mediumOpenMeasureWidth: CGFloat = 252
    private static let preferredCommittedMeasureWidth: CGFloat = 140
    private static let systemTrailingPadding: CGFloat = 6

    static func pageLayout(for chart: Chart, pageSize: CGSize) -> LeadSheetPageLayout {
        let resolvedPageSize = CGSize(
            width: max(pageSize.width, 900),
            height: max(pageSize.height, 1100)
        )
        let pageBounds = CGRect(origin: .zero, size: resolvedPageSize)
        let paperWidth = min(860, max(640, resolvedPageSize.width - 140))
        let horizontalInset = max(40, (resolvedPageSize.width - paperWidth) / 2)
        let paperX = horizontalInset
        let paperY: CGFloat = 30
        let paperHeight = max(
            resolvedPageSize.height - 60,
            estimatedPaperHeight(for: chart, paperWidth: paperWidth)
        )
        let paperFrame = CGRect(x: paperX, y: paperY, width: paperWidth, height: paperHeight)

        let headerFrame = CGRect(
            x: paperFrame.minX + 34,
            y: paperFrame.minY + 24,
            width: paperFrame.width - 68,
            height: 108
        )
        let header = headerLayout(for: chart, in: headerFrame)

        let systemFrames = systemLayouts(
            for: chart,
            paperFrame: paperFrame,
            firstSystemTop: headerFrame.maxY + 24
        )

        return LeadSheetPageLayout(
            pageBounds: pageBounds,
            paperFrame: paperFrame,
            header: header,
            systems: systemFrames
        )
    }

    private static func estimatedPaperHeight(for chart: Chart, paperWidth: CGFloat) -> CGFloat {
        let systemCount = max(1, packedSystemPlans(for: chart, maxSystemWidth: paperWidth - 68).count)
        let headerHeight: CGFloat = 164
        let footerHeight: CGFloat = 54
        let systemHeight: CGFloat = 106
        let systemSpacing: CGFloat = 22
        return headerHeight
            + CGFloat(systemCount) * systemHeight
            + CGFloat(max(0, systemCount - 1)) * systemSpacing
            + footerHeight
            + max(0, paperWidth * 0.18)
    }

    static func estimatedSystemCount(for chart: Chart, pageWidth: CGFloat) -> Int {
        let resolvedPageWidth = max(pageWidth, 900)
        let paperWidth = min(860, max(640, resolvedPageWidth - 140))
        return max(1, packedSystemPlans(for: chart, maxSystemWidth: paperWidth - 68).count)
    }

    private static func headerLayout(for chart: Chart, in frame: CGRect) -> LeadSheetHeaderLayout {
        let titleWidth = frame.width * 0.62
        let titleFrame = CGRect(
            x: frame.midX - titleWidth / 2,
            y: frame.minY + 20,
            width: titleWidth,
            height: 44
        )
        let composerFrame: CGRect?
        if let composerCredit = normalizedText(chart.composerCredit), !composerCredit.isEmpty {
            composerFrame = CGRect(
                x: frame.maxX - 190,
                y: titleFrame.minY + 10,
                width: 190,
                height: 20
            )
        } else {
            composerFrame = nil
        }

        let styleNoteFrame: CGRect?
        if let styleNote = resolvedStyleNote(for: chart), !styleNote.isEmpty {
            styleNoteFrame = CGRect(
                x: frame.minX,
                y: titleFrame.maxY + 2,
                width: 180,
                height: 18
            )
        } else {
            styleNoteFrame = nil
        }

        let keyFrame = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: 80,
            height: 18
        )
        let meterFrame = CGRect(
            x: frame.minX,
            y: frame.minY + 18,
            width: 80,
            height: 18
        )

        return LeadSheetHeaderLayout(
            frame: frame,
            titleFrame: titleFrame,
            composerFrame: composerFrame,
            styleNoteFrame: styleNoteFrame,
            keyFrame: keyFrame,
            meterFrame: meterFrame
        )
    }

    private static func systemLayouts(
        for chart: Chart,
        paperFrame: CGRect,
        firstSystemTop: CGFloat
    ) -> [LeadSheetSystemLayout] {
        let plans = packedSystemPlans(for: chart, maxSystemWidth: paperFrame.width - 68)
        let systemHeight: CGFloat = 106
        let systemSpacing: CGFloat = 22

        return plans.enumerated().map { systemIndex, plan in
            let systemFrame = CGRect(
                x: paperFrame.minX + 34,
                y: firstSystemTop + CGFloat(systemIndex) * (systemHeight + systemSpacing),
                width: min(paperFrame.width - 68, plan.frameWidth),
                height: systemHeight
            )
            return systemLayout(for: plan, chart: chart, index: systemIndex, frame: systemFrame)
        }
    }

    private static func systemLayout(
        for plan: PackedLeadSheetSystemPlan,
        chart: Chart,
        index: Int,
        frame: CGRect
    ) -> LeadSheetSystemLayout {
        let lineSpacing: CGFloat = 10.5
        let chordBandHeight: CGFloat = 26
        let staffTop = frame.minY + 28
        let staffLineYPositions = (0..<5).map { staffTop + CGFloat($0) * lineSpacing }
        let staffFrame = CGRect(
            x: frame.minX,
            y: staffTop - 2,
            width: frame.width,
            height: lineSpacing * 4 + 4
        )
        let measureStartX = frame.minX + plan.leadingSignatureWidth

        let clefFrame = index == 0
            ? CGRect(x: frame.minX, y: staffTop - 12, width: 26, height: 54)
            : nil
        let timeSignatureFrame = index == 0
            ? CGRect(x: frame.minX + 28, y: staffTop - 10, width: 24, height: 50)
            : nil
        let measureIDs = plan.measures.compactMap(\.measure?.id)
        let sectionText = chart.sectionLabels.first(where: { measureIDs.contains($0.anchorMeasureID) })?.text
        let sectionTextFrame = sectionText.map { _ in
            CGRect(x: frame.minX, y: frame.minY + 2, width: 140, height: 18)
        }
        let roadmapText = chart.roadmapObjects.first(where: {
            measureIDs.contains($0.startMeasureID) || ($0.endMeasureID.map(measureIDs.contains) ?? false)
        })?.resolvedDisplayText
        let roadmapTextFrame = roadmapText.map { _ in
            CGRect(x: frame.maxX - 160, y: frame.minY + 2, width: 160, height: 18)
        }

        var measureX = measureStartX
        let measures = plan.measures.enumerated().map { offset, measurePlan in
            defer {
                measureX += measurePlan.width
            }

            return measureLayout(
                for: measurePlan.measure,
                chart: chart,
                index: offset,
                frame: CGRect(
                    x: measureX,
                    y: frame.minY,
                    width: measurePlan.width,
                    height: frame.height
                ),
                staffFrame: CGRect(
                    x: measureX,
                    y: staffFrame.minY,
                    width: measurePlan.width,
                    height: staffFrame.height
                ),
                chordBandHeight: chordBandHeight,
                staffLineYPositions: staffLineYPositions,
                trailingMeterChange: trailingMeterChange(after: measurePlan.measure, in: chart)
            )
        }

        return LeadSheetSystemLayout(
            id: plan.id,
            index: index,
            frame: frame,
            staffLineYPositions: staffLineYPositions,
            clefFrame: clefFrame,
            timeSignatureFrame: timeSignatureFrame,
            sectionTextFrame: sectionTextFrame,
            sectionText: sectionText,
            roadmapTextFrame: roadmapTextFrame,
            roadmapText: roadmapText,
            measures: measures
        )
    }

    private static func packedSystemPlans(
        for chart: Chart,
        maxSystemWidth: CGFloat
    ) -> [PackedLeadSheetSystemPlan] {
        let sourceMeasures = chart.measures
        guard !sourceMeasures.isEmpty else {
            return [
                PackedLeadSheetSystemPlan(
                    id: UUID(),
                    leadingSignatureWidth: 78,
                    frameWidth: 78 + mediumOpenMeasureWidth + systemTrailingPadding,
                    measures: [
                        PackedLeadSheetMeasurePlan(measure: nil, width: mediumOpenMeasureWidth)
                    ]
                )
            ]
        }

        var plans: [PackedLeadSheetSystemPlan] = []
        var currentMeasures: [PackedLeadSheetMeasurePlan] = []
        var currentLeadingSignatureWidth: CGFloat = 78
        var currentBodyWidth: CGFloat = 0

        func flushCurrentSystem() {
            guard !currentMeasures.isEmpty else {
                return
            }

            plans.append(
                PackedLeadSheetSystemPlan(
                    id: UUID(),
                    leadingSignatureWidth: currentLeadingSignatureWidth,
                    frameWidth: currentLeadingSignatureWidth + currentBodyWidth + systemTrailingPadding,
                    measures: currentMeasures
                )
            )
            currentMeasures = []
            currentLeadingSignatureWidth = 18
            currentBodyWidth = 0
        }

        for measure in sourceMeasures {
            let preferredWidth = preferredWidth(for: measure)
            let nextFrameWidth = currentLeadingSignatureWidth
                + currentBodyWidth
                + preferredWidth
                + systemTrailingPadding

            if !currentMeasures.isEmpty && nextFrameWidth > maxSystemWidth {
                flushCurrentSystem()
            }

            currentMeasures.append(
                PackedLeadSheetMeasurePlan(measure: measure, width: preferredWidth)
            )
            currentBodyWidth += preferredWidth
        }

        flushCurrentSystem()
        return plans
    }

    private static func preferredWidth(for measure: Measure) -> CGFloat {
        let defaultWidth = measure.authoringState == .open
            ? mediumOpenMeasureWidth
            : preferredCommittedMeasureWidth
        return measure.resolvedLayoutWidth(defaultWidth: defaultWidth)
    }

    private static func effectiveMeter(for measure: Measure?, defaultMeter: Meter) -> Meter? {
        guard let measure else {
            return nil
        }

        return measure.meterOverride ?? defaultMeter
    }

    private static func trailingMeterChange(after measure: Measure?, in chart: Chart) -> Meter? {
        guard let measure,
              let currentMeasureIndex = chart.measures.firstIndex(where: { $0.id == measure.id }) else {
            return nil
        }

        let nextMeasureIndex = currentMeasureIndex + 1
        guard chart.measures.indices.contains(nextMeasureIndex) else {
            return nil
        }

        let currentMeter = effectiveMeter(for: measure, defaultMeter: chart.defaultMeter)
        let nextMeter = effectiveMeter(for: chart.measures[nextMeasureIndex], defaultMeter: chart.defaultMeter)
        return currentMeter == nextMeter ? nil : nextMeter
    }

    private static func measureLayout(
        for measure: Measure?,
        chart: Chart,
        index: Int,
        frame: CGRect,
        staffFrame: CGRect,
        chordBandHeight: CGFloat,
        staffLineYPositions: [CGFloat],
        trailingMeterChange: Meter?
    ) -> LeadSheetMeasureLayout {
        let chordBandFrame = CGRect(
            x: frame.minX + 3,
            y: frame.minY,
            width: frame.width - 6,
            height: chordBandHeight - 4
        )
        let writableFrame = CGRect(
            x: frame.minX + 2,
            y: chordBandFrame.minY,
            width: frame.width - 4,
            height: staffFrame.maxY - chordBandFrame.minY + 8
        )
        let trailingBarlineFrame = CGRect(
            x: frame.maxX,
            y: staffFrame.minY,
            width: 1.6,
            height: staffFrame.height
        )
        let trailingMeterChangeFrame = trailingMeterChange.map { _ in
            CGRect(
                x: max(frame.minX + 8, trailingBarlineFrame.minX - 24),
                y: staffFrame.minY - 10,
                width: 20,
                height: 44
            )
        }

        guard let measure else {
            return LeadSheetMeasureLayout(
                id: UUID(),
                sourceMeasureID: nil,
                index: index + 1,
                frame: frame,
                staffFrame: staffFrame,
                chordBandFrame: chordBandFrame,
                writableFrame: writableFrame,
                chordLayouts: [],
                noteLayouts: [],
                barlineAfter: .single,
                trailingMeterChange: trailingMeterChange,
                trailingMeterChangeFrame: trailingMeterChangeFrame,
                trailingBarlineFrame: trailingBarlineFrame,
                isOpen: true
            )
        }

        let meter = measure.resolvedMeter(defaultMeter: chart.defaultMeter)
        let displayedPlacements = measure.renderedChordPlacements(defaultMeter: chart.defaultMeter)
            .sorted {
                ($0.startPosition.startOffset(in: meter) ?? 0) <
                    ($1.startPosition.startOffset(in: meter) ?? 0)
            }

        let chordLayouts = displayedPlacements.map { placement in
            chordLayout(
                for: placement,
                chart: chart,
                meter: meter,
                chordBandFrame: chordBandFrame
            )
        }
        let noteLayouts = displayedPlacements.enumerated().map { placementIndex, placement in
            noteLayout(
                for: placement,
                chart: chart,
                meter: meter,
                index: placementIndex,
                staffFrame: staffFrame,
                staffLineYPositions: staffLineYPositions
            )
        }

        return LeadSheetMeasureLayout(
            id: measure.id,
            sourceMeasureID: measure.id,
            index: measure.index,
            frame: frame,
            staffFrame: staffFrame,
            chordBandFrame: chordBandFrame,
            writableFrame: writableFrame,
            chordLayouts: chordLayouts,
            noteLayouts: noteLayouts,
            barlineAfter: measure.barlineAfter,
            trailingMeterChange: trailingMeterChange,
            trailingMeterChangeFrame: trailingMeterChangeFrame,
            trailingBarlineFrame: trailingBarlineFrame,
            isOpen: measure.authoringState == .open
        )
    }

    private static func chordLayout(
        for placement: MeasureChordPlacement,
        chart: Chart,
        meter: Meter,
        chordBandFrame: CGRect
    ) -> LeadSheetChordLayout {
        let event = placement.chordEvent.transposed(for: chart.defaultTranspositionView)
        let startFraction = placement.startPosition.startOffset(in: meter)
            .map { $0 / meter.measureLengthInWholeNotes }
            ?? 0
        let textWidth = max(24, CGFloat(max(2, event.symbol.displayText.count)) * 11)
        let chordX = min(
            max(chordBandFrame.minX + 1, chordBandFrame.minX + CGFloat(startFraction) * chordBandFrame.width - 2),
            chordBandFrame.maxX - textWidth
        )

        return LeadSheetChordLayout(
            id: placement.chordEvent.id,
            text: event.symbol.displayText,
            frame: CGRect(x: chordX, y: chordBandFrame.minY, width: textWidth, height: chordBandFrame.height)
        )
    }

    private static func noteLayout(
        for placement: MeasureChordPlacement,
        chart: Chart,
        meter: Meter,
        index: Int,
        staffFrame: CGRect,
        staffLineYPositions: [CGFloat]
    ) -> LeadSheetNoteLayout {
        let event = placement.chordEvent.transposed(for: chart.defaultTranspositionView)
        let startFraction = placement.startPosition.startOffset(in: meter)
            .map { $0 / meter.measureLengthInWholeNotes }
            ?? 0
        let usableWidth = staffFrame.width - 12
        let noteCenterX = staffFrame.minX + 8 + usableWidth * CGFloat(startFraction)
        let stepOffset = pitchStep(for: event.symbol)
        let halfStepSpacing = (staffLineYPositions[1] - staffLineYPositions[0]) / 2
        let clampedStep = min(4, max(-4, stepOffset))
        let staffMiddleY = staffLineYPositions[2]
        let unclampedCenterY = staffMiddleY - CGFloat(clampedStep) * halfStepSpacing
        let noteCenterY = min(
            max(staffFrame.minY + 5, unclampedCenterY),
            staffFrame.maxY - 5
        )
        let noteheadFrame = CGRect(x: noteCenterX - 4.5, y: noteCenterY - 3.5, width: 9, height: 7)
        let headStyle = headStyle(for: event.duration)
        let stemGoesUp = noteCenterY > staffMiddleY
        let stemLength: CGFloat = 28
        let stemStart = headStyle == .whole ? nil : CGPoint(
            x: stemGoesUp ? noteheadFrame.maxX - 0.5 : noteheadFrame.minX + 0.5,
            y: noteCenterY
        )
        let stemEnd = stemStart.map { startPoint in
            CGPoint(
                x: startPoint.x,
                y: stemGoesUp ? startPoint.y - stemLength : startPoint.y + stemLength
            )
        }
        let dotFrame = dottedDuration(event.duration)
            ? CGRect(
                x: noteheadFrame.maxX + 3,
                y: noteCenterY - 1.5,
                width: 3,
                height: 3
            )
            : nil
        let tieFrame: CGRect?
        if event.tieOut || event.duration == .whole || event.duration == .dottedHalf {
            tieFrame = CGRect(
                x: noteheadFrame.minX - 1,
                y: noteheadFrame.maxY + 7,
                width: max(18, staffFrame.maxX - noteheadFrame.minX - 8),
                height: 10
            )
        } else {
            tieFrame = nil
        }

        return LeadSheetNoteLayout(
            id: UUID(uuidString: placement.chordEvent.id.uuidString) ?? UUID(),
            noteheadFrame: noteheadFrame,
            headStyle: headStyle,
            stemStart: stemStart,
            stemEnd: stemEnd,
            stemGoesUp: stemGoesUp,
            flagStyle: event.duration == .eighth ? .single : .none,
            dotFrame: dotFrame,
            tieFrame: tieFrame
        )
    }

    private static func headStyle(for duration: RhythmValue) -> LeadSheetNoteLayout.HeadStyle {
        switch duration {
        case .whole:
            return .whole
        case .half, .dottedHalf:
            return .half
        case .quarter, .dottedQuarter, .eighth, .tiedContinuation:
            return .filled
        }
    }

    private static func dottedDuration(_ duration: RhythmValue) -> Bool {
        switch duration {
        case .dottedQuarter, .dottedHalf:
            return true
        case .eighth, .quarter, .half, .whole, .tiedContinuation:
            return false
        }
    }

    private static func pitchStep(for symbol: ChordSymbol) -> Int {
        let pitchText = symbol.slashBass ?? "\(symbol.root.rawValue)\(symbol.accidental.rawValue)"
        let pitch = ChordPitch.parse(pitchText) ?? ChordPitch(root: symbol.root, accidental: symbol.accidental)

        switch pitch.root {
        case .c:
            return -1
        case .d:
            return 0
        case .e:
            return 1
        case .f:
            return 2
        case .g:
            return 3
        case .a:
            return 4
        case .b:
            return 5
        }
    }

    static func resolvedStyleNote(for chart: Chart) -> String? {
        if let explicitStyleNote = normalizedText(chart.styleNote), !explicitStyleNote.isEmpty {
            return explicitStyleNote
        }

        switch chart.measures.first?.beatGridPreset {
        case .swung:
            return "MED. SWING"
        case .eighthSubdivision:
            return "STRAIGHT 8THS"
        case .tripletSubdivision:
            return "TRIPLET FEEL"
        case .simple, .none:
            return nil
        }
    }

    private static func normalizedText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private struct PackedLeadSheetSystemPlan: Hashable {
    var id: UUID
    var leadingSignatureWidth: CGFloat
    var frameWidth: CGFloat
    var measures: [PackedLeadSheetMeasurePlan]
}

private struct PackedLeadSheetMeasurePlan: Hashable {
    var measure: Measure?
    var width: CGFloat
}
