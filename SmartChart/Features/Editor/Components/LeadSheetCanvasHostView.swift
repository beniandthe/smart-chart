#if canImport(UIKit)
import PencilKit
import SwiftUI
import UIKit

struct LeadSheetCanvasHostView: UIViewRepresentable {
    @Binding var chart: Chart
    @Binding var selectedMeasureID: UUID?
    let interactionMode: EditorCanvasMode
    var onTimeSignatureTargetRequested: ((UUID) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(chart: $chart, selectedMeasureID: $selectedMeasureID)
    }

    func makeUIView(context: Context) -> LeadSheetCanvasUIKitView {
        let view = LeadSheetCanvasUIKitView()
        view.chart = chart
        view.selectedMeasureID = selectedMeasureID
        view.interactionMode = interactionMode
        view.onMeasureSelectionChanged = { measureID in
            context.coordinator.selectedMeasureID.wrappedValue = measureID
        }
        view.onChartChanged = { updatedChart in
            context.coordinator.chart.wrappedValue = updatedChart
        }
        view.onTimeSignatureTargetRequested = onTimeSignatureTargetRequested
        return view
    }

    func updateUIView(_ uiView: LeadSheetCanvasUIKitView, context: Context) {
        uiView.chart = chart
        uiView.selectedMeasureID = selectedMeasureID
        uiView.interactionMode = interactionMode
        uiView.onMeasureSelectionChanged = { measureID in
            context.coordinator.selectedMeasureID.wrappedValue = measureID
        }
        uiView.onChartChanged = { updatedChart in
            context.coordinator.chart.wrappedValue = updatedChart
        }
        uiView.onTimeSignatureTargetRequested = onTimeSignatureTargetRequested
    }

    final class Coordinator {
        var chart: Binding<Chart>
        var selectedMeasureID: Binding<UUID?>

        init(chart: Binding<Chart>, selectedMeasureID: Binding<UUID?>) {
            self.chart = chart
            self.selectedMeasureID = selectedMeasureID
        }
    }
}

final class LeadSheetCanvasUIKitView: UIView, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    var chart: Chart = .draft(title: "Preview") {
        didSet {
            guard oldValue != chart else {
                return
            }

            invalidateLayout()
        }
    }
    var selectedMeasureID: UUID? {
        didSet {
            guard oldValue != selectedMeasureID else {
                return
            }

            setNeedsDisplay()
        }
    }
    var interactionMode: EditorCanvasMode = .browse {
        didSet {
            guard oldValue != interactionMode else {
                return
            }

            if !interactionMode.allowsPageInkEditing {
                persistActiveInkIfNeeded()
            }

            updateInteractionMode()
            syncPageInkCanvas()
            setNeedsDisplay()
        }
    }
    var onMeasureSelectionChanged: ((UUID?) -> Void)?
    var onChartChanged: ((Chart) -> Void)?
    var onTimeSignatureTargetRequested: ((UUID) -> Void)?

    private var pageLayout: LeadSheetPageLayout?
    private let pageInkCanvasView = PKCanvasView()
    private lazy var selectionTapRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(handleTap(_:))
    )
    private lazy var measureResizePanRecognizer = UIPanGestureRecognizer(
        target: self,
        action: #selector(handleMeasureResizePan(_:))
    )
    private var isSyncingInkCanvasFromModel = false
    private var pendingInkPersistWorkItem: DispatchWorkItem?
    private var activeMeasureResizeDrag: ActiveMeasureResizeDrag?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateLayout()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let pageLayout else {
            return
        }

        context.clear(rect)
        drawPaper(pageLayout.paperFrame, in: context)
        drawHeader(pageLayout.header)

        for system in pageLayout.systems {
            drawSystem(system)
        }

        if !interactionMode.allowsPageInkEditing {
            drawSavedPageInk()
        }

        if interactionMode.showsMeasureResizeHandles,
           let selectedMeasure = selectedMeasureLayout() {
            drawMeasureResizeHandles(for: selectedMeasure)
        }
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        selectionTapRecognizer.delegate = self
        addGestureRecognizer(selectionTapRecognizer)
        measureResizePanRecognizer.delegate = self
        selectionTapRecognizer.require(toFail: measureResizePanRecognizer)
        addGestureRecognizer(measureResizePanRecognizer)

        pageInkCanvasView.backgroundColor = .clear
        pageInkCanvasView.isOpaque = false
        pageInkCanvasView.delegate = self
        pageInkCanvasView.isScrollEnabled = false
        pageInkCanvasView.bounces = false
        pageInkCanvasView.alwaysBounceVertical = false
        pageInkCanvasView.alwaysBounceHorizontal = false
        pageInkCanvasView.drawingPolicy = .anyInput
        pageInkCanvasView.tool = PKInkingTool(.pen, color: UIColor(white: 0.06, alpha: 1), width: 2.8)
        pageInkCanvasView.isHidden = true
        addSubview(pageInkCanvasView)
        updateInteractionMode()
    }

    private func invalidateLayout() {
        guard bounds.width > 0, bounds.height > 0 else {
            pageLayout = nil
            syncPageInkCanvas()
            setNeedsDisplay()
            return
        }

        pageLayout = LeadSheetPageLayoutEngine.pageLayout(for: chart, pageSize: bounds.size)
        syncPageInkCanvas()
        setNeedsDisplay()
    }

    private func drawPaper(_ frame: CGRect, in context: CGContext) {
        context.saveGState()
        let shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        context.setShadow(offset: CGSize(width: 0, height: 8), blur: 24, color: shadowColor)
        let shadowPath = UIBezierPath(roundedRect: frame, cornerRadius: 4)
        UIColor.white.setFill()
        shadowPath.fill()
        context.restoreGState()

        let paperPath = UIBezierPath(rect: frame)
        UIColor(white: 0.995, alpha: 1).setFill()
        paperPath.fill()
        UIColor(white: 0.35, alpha: 1).setStroke()
        paperPath.lineWidth = 1.2
        paperPath.stroke()
    }

    private func drawHeader(_ header: LeadSheetHeaderLayout) {
        let title = chart.title.trimmingCharacters(in: .whitespacesAndNewlines)
        drawText(
            title.isEmpty ? "UNTITLED CHART" : title.uppercased(),
            in: header.titleFrame,
            font: markerFont(size: 38, weight: .regular),
            color: UIColor(white: 0.06, alpha: 1),
            alignment: .center
        )

        if let composerFrame = header.composerFrame,
           let composerCredit = normalizedText(chart.composerCredit) {
            drawText(
                "—\(composerCredit)",
                in: composerFrame,
                font: markerFont(size: 16, weight: .regular),
                color: UIColor(white: 0.12, alpha: 1),
                alignment: .right
            )
        }

        if let styleNoteFrame = header.styleNoteFrame,
           let styleNote = LeadSheetPageLayoutEngine.resolvedStyleNote(for: chart) {
            drawText(
                "(\(styleNote))",
                in: styleNoteFrame,
                font: markerFont(size: 15, weight: .regular),
                color: UIColor(white: 0.14, alpha: 1)
            )
        }

        drawText(
            chart.documentKey.transposed(for: chart.defaultTranspositionView).displayText.uppercased(),
            in: header.keyFrame,
            font: markerFont(size: 14, weight: .regular),
            color: UIColor(white: 0.14, alpha: 1)
        )
        drawText(
            chart.defaultMeter.displayText,
            in: header.meterFrame,
            font: markerFont(size: 14, weight: .regular),
            color: UIColor(white: 0.14, alpha: 1)
        )

        let underlinePath = UIBezierPath()
        underlinePath.move(to: CGPoint(x: header.titleFrame.minX + 28, y: header.titleFrame.maxY - 4))
        underlinePath.addLine(to: CGPoint(x: header.titleFrame.maxX - 28, y: header.titleFrame.maxY - 4))
        underlinePath.lineWidth = 2.6
        UIColor(white: 0.08, alpha: 1).setStroke()
        underlinePath.stroke()
    }

    private func drawSystem(_ system: LeadSheetSystemLayout) {
        if let sectionTextFrame = system.sectionTextFrame,
           let sectionText = system.sectionText {
            drawText(
                sectionText.uppercased(),
                in: sectionTextFrame,
                font: markerFont(size: 15, weight: .regular),
                color: UIColor(white: 0.12, alpha: 1)
            )
        }

        if let roadmapTextFrame = system.roadmapTextFrame,
           let roadmapText = system.roadmapText {
            drawText(
                roadmapText.uppercased(),
                in: roadmapTextFrame,
                font: markerFont(size: 13, weight: .regular),
                color: UIColor(white: 0.22, alpha: 1),
                alignment: .right
            )
        }

        drawStaffLines(for: system)

        if let clefFrame = system.clefFrame {
            drawText(
                "𝄞",
                in: clefFrame,
                font: UIFont.systemFont(ofSize: 40),
                color: UIColor(white: 0.08, alpha: 1),
                alignment: .center
            )
        }

        if let timeSignatureFrame = system.timeSignatureFrame {
            drawStackedTimeSignature(chart.defaultMeter, in: timeSignatureFrame)
        }

        if let firstMeasure = system.measures.first {
            drawSingleBarline(at: firstMeasure.frame.minX, from: firstMeasure.staffFrame.minY, to: firstMeasure.staffFrame.maxY, width: 1.5)
        }

        for measure in system.measures {
            if measure.sourceMeasureID == selectedMeasureID {
                drawMeasureSelection(measure)
            }

            for chordLayout in measure.chordLayouts {
                drawText(
                    chordLayout.text,
                    in: chordLayout.frame,
                    font: markerFont(size: 18, weight: .regular),
                    color: UIColor(white: 0.06, alpha: 1)
                )
            }

            for noteLayout in measure.noteLayouts {
                drawNote(noteLayout)
            }

            if let trailingMeterChange = measure.trailingMeterChange,
               let trailingMeterChangeFrame = measure.trailingMeterChangeFrame {
                drawStackedTimeSignature(trailingMeterChange, in: trailingMeterChangeFrame)
            }

            if measure.isOpen {
                drawOpenMeasureHint(measure)
            } else {
                drawBarline(measure.barlineAfter, in: measure.trailingBarlineFrame)
            }
        }
    }

    private func drawMeasureSelection(_ measure: LeadSheetMeasureLayout) {
        let selectionRect = measure.frame.insetBy(dx: 2, dy: 10)
        let selectionPath = UIBezierPath(roundedRect: selectionRect, cornerRadius: 8)
        UIColor(red: 0.89, green: 0.94, blue: 1, alpha: 0.42).setFill()
        selectionPath.fill()
        UIColor(red: 0.21, green: 0.43, blue: 0.83, alpha: 0.45).setStroke()
        selectionPath.lineWidth = 1.2
        selectionPath.stroke()
    }

    private func drawMeasureResizeHandles(for measure: LeadSheetMeasureLayout) {
        let handleRects = measureResizeHandleRects(for: measure)
        drawMeasureResizeHandle(handleRects.left, symbol: "⇠")
        drawMeasureResizeHandle(handleRects.right, symbol: "⇢")
    }

    private func drawMeasureResizeHandle(_ rect: CGRect, symbol: String) {
        let handlePath = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor.white.withAlphaComponent(0.95).setFill()
        handlePath.fill()
        UIColor(red: 0.18, green: 0.38, blue: 0.78, alpha: 0.88).setStroke()
        handlePath.lineWidth = 1.2
        handlePath.stroke()

        drawText(
            symbol,
            in: rect.insetBy(dx: 1, dy: 3),
            font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            color: UIColor(red: 0.16, green: 0.33, blue: 0.68, alpha: 1),
            alignment: .center
        )
    }

    private func drawSavedPageInk() {
        guard let pageLayout,
              let drawingData = chart.pageHandwrittenNotationData,
              let drawing = try? PKDrawing(data: drawingData),
              !drawing.strokes.isEmpty else {
            return
        }

        let writingFrame = pageWritingFrame(for: pageLayout)
        let image = drawing.image(
            from: CGRect(origin: .zero, size: writingFrame.size),
            scale: UIScreen.main.scale
        )
        image.draw(in: writingFrame)
    }

    private func drawStackedTimeSignature(_ meter: Meter, in frame: CGRect) {
        let numeratorRect = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height / 2
        )
        let denominatorRect = CGRect(
            x: frame.minX,
            y: frame.midY - 2,
            width: frame.width,
            height: frame.height / 2
        )

        drawText(
            "\(meter.numerator)",
            in: numeratorRect,
            font: markerFont(size: 22, weight: .regular),
            color: UIColor(white: 0.08, alpha: 1),
            alignment: .center
        )
        drawText(
            "\(meter.denominator)",
            in: denominatorRect,
            font: markerFont(size: 22, weight: .regular),
            color: UIColor(white: 0.08, alpha: 1),
            alignment: .center
        )
    }

    private func drawStaffLines(for system: LeadSheetSystemLayout) {
        for lineY in system.staffLineYPositions {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: system.frame.minX, y: lineY))
            path.addLine(to: CGPoint(x: system.frame.maxX, y: lineY))
            path.lineWidth = 1
            UIColor(white: 0.15, alpha: 1).setStroke()
            path.stroke()
        }
    }

    private func drawBarline(_ barline: BarlineType, in frame: CGRect) {
        switch barline {
        case .single:
            drawSingleBarline(at: frame.midX, from: frame.minY, to: frame.maxY, width: 1.4)
        case .double:
            drawSingleBarline(at: frame.midX - 2.5, from: frame.minY, to: frame.maxY, width: 1.1)
            drawSingleBarline(at: frame.midX + 1.5, from: frame.minY, to: frame.maxY, width: 1.4)
        case .final:
            drawSingleBarline(at: frame.midX - 3.5, from: frame.minY, to: frame.maxY, width: 1.1)
            drawSingleBarline(at: frame.midX + 1.5, from: frame.minY, to: frame.maxY, width: 2.6)
        }
    }

    private func drawSingleBarline(at x: CGFloat, from startY: CGFloat, to endY: CGFloat, width: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: startY))
        path.addLine(to: CGPoint(x: x, y: endY))
        path.lineWidth = width
        UIColor(white: 0.1, alpha: 1).setStroke()
        path.stroke()
    }

    private func drawNote(_ noteLayout: LeadSheetNoteLayout) {
        let notePath = UIBezierPath(ovalIn: noteLayout.noteheadFrame)

        switch noteLayout.headStyle {
        case .whole:
            UIColor.white.setFill()
            notePath.fill()
            UIColor(white: 0.08, alpha: 1).setStroke()
            notePath.lineWidth = 1.5
            notePath.stroke()
        case .half:
            UIColor.white.setFill()
            notePath.fill()
            UIColor(white: 0.08, alpha: 1).setStroke()
            notePath.lineWidth = 1.5
            notePath.stroke()
        case .filled:
            UIColor(white: 0.05, alpha: 1).setFill()
            notePath.fill()
        }

        if let stemStart = noteLayout.stemStart,
           let stemEnd = noteLayout.stemEnd {
            let stemPath = UIBezierPath()
            stemPath.move(to: stemStart)
            stemPath.addLine(to: stemEnd)
            stemPath.lineWidth = 1.2
            UIColor(white: 0.06, alpha: 1).setStroke()
            stemPath.stroke()

            if noteLayout.flagStyle == .single {
                let flagPath = UIBezierPath()
                if noteLayout.stemGoesUp {
                    flagPath.move(to: stemEnd)
                    flagPath.addCurve(
                        to: CGPoint(x: stemEnd.x + 6, y: stemEnd.y + 10),
                        controlPoint1: CGPoint(x: stemEnd.x + 8, y: stemEnd.y + 2),
                        controlPoint2: CGPoint(x: stemEnd.x + 9, y: stemEnd.y + 7)
                    )
                } else {
                    flagPath.move(to: stemEnd)
                    flagPath.addCurve(
                        to: CGPoint(x: stemEnd.x + 6, y: stemEnd.y - 10),
                        controlPoint1: CGPoint(x: stemEnd.x + 8, y: stemEnd.y - 2),
                        controlPoint2: CGPoint(x: stemEnd.x + 9, y: stemEnd.y - 7)
                    )
                }
                flagPath.lineWidth = 1.2
                UIColor(white: 0.06, alpha: 1).setStroke()
                flagPath.stroke()
            }
        }

        if let dotFrame = noteLayout.dotFrame {
            let dotPath = UIBezierPath(ovalIn: dotFrame)
            UIColor(white: 0.06, alpha: 1).setFill()
            dotPath.fill()
        }

        if let tieFrame = noteLayout.tieFrame {
            let tiePath = UIBezierPath()
            tiePath.move(to: CGPoint(x: tieFrame.minX, y: tieFrame.midY))
            tiePath.addCurve(
                to: CGPoint(x: tieFrame.maxX, y: tieFrame.midY),
                controlPoint1: CGPoint(x: tieFrame.minX + tieFrame.width * 0.28, y: tieFrame.maxY),
                controlPoint2: CGPoint(x: tieFrame.maxX - tieFrame.width * 0.28, y: tieFrame.maxY)
            )
            tiePath.lineWidth = 1.1
            UIColor(white: 0.06, alpha: 1).setStroke()
            tiePath.stroke()
        }
    }

    private func drawOpenMeasureHint(_ measure: LeadSheetMeasureLayout) {
        let guidePath = UIBezierPath()
        guidePath.move(to: CGPoint(x: measure.trailingBarlineFrame.midX, y: measure.staffFrame.minY))
        guidePath.addLine(to: CGPoint(x: measure.trailingBarlineFrame.midX, y: measure.staffFrame.maxY))
        guidePath.lineWidth = 1
        guidePath.setLineDash([4, 4], count: 2, phase: 0)
        UIColor(white: 0.55, alpha: 0.6).setStroke()
        guidePath.stroke()
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes,
            context: nil
        )
    }

    private func markerFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let markerFelt = UIFont(name: "MarkerFelt-Wide", size: size) {
            return markerFelt
        }

        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    private func normalizedText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func selectedMeasureLayout() -> LeadSheetMeasureLayout? {
        guard let selectedMeasureID else {
            return nil
        }

        return pageLayout?.systems
            .flatMap(\.measures)
            .first(where: { $0.sourceMeasureID == selectedMeasureID })
    }

    private func measureResizeHandleRects(
        for measure: LeadSheetMeasureLayout
    ) -> (left: CGRect, right: CGRect) {
        let handleSize = CGSize(width: 18, height: 34)
        let handleY = measure.staffFrame.midY - handleSize.height / 2
        let leftRect = CGRect(
            x: measure.frame.minX - handleSize.width / 2,
            y: handleY,
            width: handleSize.width,
            height: handleSize.height
        )
        let rightRect = CGRect(
            x: measure.frame.maxX - handleSize.width / 2,
            y: handleY,
            width: handleSize.width,
            height: handleSize.height
        )
        return (leftRect, rightRect)
    }

    private func measureResizeHandleHitTarget(at location: CGPoint) -> ActiveMeasureResizeDrag? {
        guard interactionMode.showsMeasureResizeHandles,
              let measure = selectedMeasureLayout(),
              let measureID = measure.sourceMeasureID else {
            return nil
        }

        let handleRects = measureResizeHandleRects(for: measure)
        let touchInsetX: CGFloat = -12
        let touchInsetY: CGFloat = -10

        if handleRects.left.insetBy(dx: touchInsetX, dy: touchInsetY).contains(location) {
            return ActiveMeasureResizeDrag(
                measureID: measureID,
                edge: .left,
                initialWidth: measure.frame.width
            )
        }

        if handleRects.right.insetBy(dx: touchInsetX, dy: touchInsetY).contains(location) {
            return ActiveMeasureResizeDrag(
                measureID: measureID,
                edge: .right,
                initialWidth: measure.frame.width
            )
        }

        return nil
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isSyncingInkCanvasFromModel else {
            return
        }

        schedulePersistActiveInk()
    }

    @objc
    private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard interactionMode.allowsMeasureSelection else {
            return
        }

        let location = recognizer.location(in: self)
        let tappedMeasureID = pageLayout?.systems
            .flatMap(\.measures)
            .first(where: { $0.frame.insetBy(dx: -6, dy: -6).contains(location) })?
            .sourceMeasureID
        onMeasureSelectionChanged?(tappedMeasureID)

        if interactionMode.showsTimeSignatureTargeting,
           let tappedMeasureID {
            onTimeSignatureTargetRequested?(tappedMeasureID)
        }
    }

    @objc
    private func handleMeasureResizePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: self)
            activeMeasureResizeDrag = measureResizeHandleHitTarget(at: location)
        case .changed:
            guard let activeMeasureResizeDrag else {
                return
            }

            let translation = recognizer.translation(in: self)
            let signedDelta = activeMeasureResizeDrag.edge == .right
                ? translation.x
                : -translation.x
            let proposedWidth = activeMeasureResizeDrag.initialWidth + signedDelta

            var updatedChart = chart
            let appliedWidth = updatedChart.setMeasureManualLayoutWidth(
                proposedWidth,
                for: activeMeasureResizeDrag.measureID
            )
            guard appliedWidth != nil else {
                return
            }

            chart = updatedChart
            onChartChanged?(updatedChart)
        case .ended, .cancelled, .failed:
            activeMeasureResizeDrag = nil
        default:
            break
        }
    }

    private func syncPageInkCanvas() {
        guard interactionMode.allowsPageInkEditing else {
            pageInkCanvasView.isHidden = true
            pageInkCanvasView.isUserInteractionEnabled = false
            return
        }

        guard let pageLayout else {
            persistActiveInkIfNeeded()
            pageInkCanvasView.isHidden = true
            return
        }

        let writingFrame = pageWritingFrame(for: pageLayout)
        pageInkCanvasView.isHidden = false
        pageInkCanvasView.isUserInteractionEnabled = true
        pageInkCanvasView.frame = writingFrame
        pageInkCanvasView.contentSize = writingFrame.size

        let desiredData = chart.pageHandwrittenNotationData
        let currentData = currentCanvasDrawingData()
        guard currentData != desiredData else {
            return
        }

        isSyncingInkCanvasFromModel = true
        if let desiredData,
           let drawing = try? PKDrawing(data: desiredData) {
            pageInkCanvasView.drawing = drawing
        } else {
            pageInkCanvasView.drawing = PKDrawing()
        }
        isSyncingInkCanvasFromModel = false
        pageInkCanvasView.becomeFirstResponder()
    }

    private func schedulePersistActiveInk() {
        pendingInkPersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistActiveInkIfNeeded()
        }
        pendingInkPersistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: workItem)
    }

    private func persistActiveInkIfNeeded() {
        pendingInkPersistWorkItem?.cancel()
        pendingInkPersistWorkItem = nil

        let drawingData = currentCanvasDrawingData()
        guard chart.pageHandwrittenNotationData != drawingData else {
            return
        }

        var updatedChart = chart
        guard updatedChart.setPageHandwrittenNotationDrawing(drawingData) else {
            return
        }

        chart = updatedChart
        onChartChanged?(updatedChart)
    }

    private func currentCanvasDrawingData() -> Data? {
        let drawing = pageInkCanvasView.drawing
        return drawing.strokes.isEmpty ? nil : drawing.dataRepresentation()
    }

    private func updateInteractionMode() {
        selectionTapRecognizer.isEnabled = interactionMode.allowsMeasureSelection
        measureResizePanRecognizer.isEnabled = interactionMode.showsMeasureResizeHandles
        pageInkCanvasView.isUserInteractionEnabled = interactionMode.allowsPageInkEditing

        if !interactionMode.showsMeasureResizeHandles {
            activeMeasureResizeDrag = nil
        }

        if !interactionMode.allowsPageInkEditing {
            pageInkCanvasView.isHidden = true
            pageInkCanvasView.resignFirstResponder()
        }
    }

    private func pageWritingFrame(for pageLayout: LeadSheetPageLayout) -> CGRect {
        pageLayout.paperFrame.insetBy(dx: 10, dy: 10)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === measureResizePanRecognizer {
            let location = gestureRecognizer.location(in: self)
            return measureResizeHandleHitTarget(at: location) != nil
        }

        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private struct ActiveMeasureResizeDrag {
    enum Edge {
        case left
        case right
    }

    var measureID: UUID
    var edge: Edge
    var initialWidth: CGFloat
}
#endif
