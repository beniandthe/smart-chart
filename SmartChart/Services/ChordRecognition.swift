import CoreGraphics
import Foundation
#if canImport(PencilKit)
import PencilKit
#endif

enum ChordRecognitionMethod: String, CaseIterable, Hashable {
    case confirmedExample
    case confirmedBoundary
    case textOCRExact
    case strokeRootShape
    case rasterTemplate
}

// Compatibility shims keep older fixtures readable while the production pipeline uses chord-wide names.
typealias BasicMajorChordRecognitionMethod = ChordRecognitionMethod

struct ChordRecognitionCandidate: Hashable {
    var method: ChordRecognitionMethod
    var match: ChordRecognitionMatch
    var confidence: Double
    var debugSummary: String
}

typealias BasicMajorChordRecognitionCandidate = ChordRecognitionCandidate

struct ChordRecognitionReport {
    var candidates: [ChordRecognitionCandidate]

    var strongestCandidatesBySymbol: [ChordRecognitionCandidate] {
        sortedCandidates(
            resolvedCandidates(from: symbolEvaluations)
        )
    }

    private var symbolEvaluations: [SymbolCandidateEvaluation] {
        let groupedCandidates = Dictionary(grouping: candidates) { candidate in
            candidate.match.displayText
        }

        return groupedCandidates.values.compactMap(symbolEvaluation)
    }

    private func symbolEvaluation(
        for candidatesForSymbol: [ChordRecognitionCandidate]
    ) -> SymbolCandidateEvaluation? {
        guard var strongest = candidatesForSymbol.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }

        let containsExactText = candidatesForSymbol.contains { $0.method == .textOCRExact }
        let agreementMethods = Set(
            candidatesForSymbol
                .filter { candidate in
                    candidate.method != .confirmedBoundary
                        && !candidate.hasLearnedCorrectionPenalty
                }
                .map(\.method)
        )
        let boostPerCandidate = containsExactText ? 0.06 : 0.03
        let maximumBoost = containsExactText ? 0.12 : 0.04
        let agreementBoost = min(maximumBoost, Double(max(0, agreementMethods.count - 1)) * boostPerCandidate)
        let rawConfidence = strongest.confidence
        let strongestSourceSummary = strongest.debugSummary
        strongest.confidence = max(strongest.confidence, min(0.99, strongest.confidence + agreementBoost))
        strongest.debugSummary = candidatesForSymbol
            .sorted { $0.confidence > $1.confidence }
            .map { "\($0.method.rawValue)=\(String(format: "%.2f", $0.confidence))" }
            .joined(separator: ", ")
        strongest.debugSummary += " best={\(strongestSourceSummary)}"

        return SymbolCandidateEvaluation(
            candidate: strongest,
            rawConfidence: rawConfidence,
            agreementBoost: agreementBoost,
            strongestConfirmedExample: candidatesForSymbol
                .filter { $0.method == .confirmedExample }
                .max(by: { $0.confidence < $1.confidence }),
            hasPenalizedHeuristicSupport: candidatesForSymbol.contains { candidate in
                candidate.hasLearnedCorrectionPenalty
                    && (candidate.method == .strokeRootShape || candidate.method == .rasterTemplate)
            }
        )
    }

    private func resolvedCandidates(
        from evaluations: [SymbolCandidateEvaluation]
    ) -> [ChordRecognitionCandidate] {
        accidentalRootResolvedCandidates(
            flatMinorDirectRootResolvedCandidates(
                bbFlatMinorCloseRaceResolvedCandidates(
                    minorNaturalRootCloseRaceResolvedCandidates(
                        closeRaceResolvedCandidates(from: evaluations)
                    )
                )
            )
        )
    }

    private func sortedCandidates(
        _ candidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        candidates.sorted { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.0001 {
                return lhs.confidence > rhs.confidence
            }

            let lhsMethodPriority = methodPriority(lhs.method)
            let rhsMethodPriority = methodPriority(rhs.method)
            if lhsMethodPriority != rhsMethodPriority {
                return lhsMethodPriority > rhsMethodPriority
            }

            let lhsAccidentalPriority = lhs.match.symbol.accidental == .natural ? 0 : 1
            let rhsAccidentalPriority = rhs.match.symbol.accidental == .natural ? 0 : 1
            if lhsAccidentalPriority != rhsAccidentalPriority {
                return lhsAccidentalPriority > rhsAccidentalPriority
            }

            return lhs.match.displayText < rhs.match.displayText
        }
    }

    private func accidentalRootResolvedCandidates(
        _ candidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        var resolvedCandidates = candidates

        for index in resolvedCandidates.indices {
            let candidate = resolvedCandidates[index]
            guard candidate.match.symbol.quality == "-",
                  candidate.match.symbol.accidental == .natural else {
                continue
            }

            guard let accidentalCandidate = candidates
                .filter({
                    $0.match.symbol.root == candidate.match.symbol.root
                        && $0.match.symbol.accidental != .natural
                        && $0.match.symbol.quality.isEmpty
                })
                .max(by: { $0.confidence < $1.confidence }) else {
                continue
            }

            let gap = candidate.confidence - accidentalCandidate.confidence
            guard gap >= 0,
                  gap <= 0.045 else {
                continue
            }

            resolvedCandidates[index].confidence = max(0.50, accidentalCandidate.confidence - 0.001)
            resolvedCandidates[index].debugSummary += " accidentalRootCloseRacePenalty=\(String(format: "%.3f", gap))"
        }

        return resolvedCandidates
    }

    private func bbFlatMinorCloseRaceResolvedCandidates(
        _ candidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        let closeRaceSymbols: Set<String> = [
            "B-", "C-", "Db", "Db-", "Eb", "Eb-", "Fb", "Fb-", "F-", "Gb", "Gb-", "G-"
        ]

        guard candidates.count > 1,
              let bbIndex = candidates.firstIndex(where: {
                  $0.match.displayText == "Bb-" && $0.hasBFlatMinorShapeSupport
              }) else {
            return candidates
        }

        let bbCandidate = candidates[bbIndex]
        let confidenceFloor = bbCandidate.hasFlatMinorSecondaryBRootRescue ? 0.76 : 0.775
        let maximumGap = bbCandidate.hasFlatMinorSecondaryBRootRescue ? 0.14 : 0.02
        guard bbCandidate.confidence >= confidenceFloor,
              candidates.contains(where: { candidate in
                  canResolveBFlatMinorCloseRace(
                      competitor: candidate,
                      bFlatMinorCandidate: bbCandidate,
                      closeRaceSymbols: closeRaceSymbols,
                      maximumGap: maximumGap
                  )
              }) else {
            return candidates
        }

        var resolvedCandidates = candidates
        for index in resolvedCandidates.indices {
            guard index != bbIndex,
                  canResolveBFlatMinorCloseRace(
                      competitor: resolvedCandidates[index],
                      bFlatMinorCandidate: bbCandidate,
                      closeRaceSymbols: closeRaceSymbols,
                      maximumGap: maximumGap
                  ) else {
                continue
            }

            let competingSymbol = resolvedCandidates[index].match.displayText
            let gap = resolvedCandidates[index].confidence - bbCandidate.confidence
            resolvedCandidates[index].confidence = max(0.50, bbCandidate.confidence - 0.001)
            resolvedCandidates[index].debugSummary += " bbFlatMinorCloseRacePenalty=\(competingSymbol) gap=\(String(format: "%.3f", gap))"
            resolvedCandidates[bbIndex].debugSummary += " bbFlatMinorCloseRacePreferred=\(competingSymbol) gap=\(String(format: "%.3f", gap))"
        }

        return resolvedCandidates
    }

    private func flatMinorDirectRootResolvedCandidates(
        _ candidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        guard candidates.count > 1 else {
            return candidates
        }

        var resolvedCandidates = candidates
        for index in resolvedCandidates.indices {
            let rescuedCandidate = resolvedCandidates[index]
            guard rescuedCandidate.isFlatMinor,
                  rescuedCandidate.hasFlatMinorSecondaryRootRescue else {
                continue
            }

            guard let directChallenger = candidates
                .filter({
                    $0.match.displayText != rescuedCandidate.match.displayText
                        && $0.isFlatMinor
                        && $0.hasDirectFlatRootSupport
                        && !$0.hasFlatMinorSecondaryRootRescue
                        && !$0.hasBFlatMinorCloseRacePenalty
                        && canDirectFlatMinorRootChallenge(
                            challenger: $0,
                            rescuedCandidate: rescuedCandidate
                        )
                })
                .max(by: { $0.confidence < $1.confidence }) else {
                continue
            }

            let gap = rescuedCandidate.confidence - directChallenger.confidence
            guard gap >= -0.001,
                  gap <= flatMinorDirectRootChallengeGap(
                      challenger: directChallenger,
                      rescuedCandidate: rescuedCandidate
                  ) else {
                continue
            }

            resolvedCandidates[index].confidence = max(0.50, directChallenger.confidence - 0.001)
            resolvedCandidates[index].debugSummary += " flatMinorDirectRootPreferred=\(directChallenger.match.displayText) gap=\(String(format: "%.3f", gap))"
        }

        return resolvedCandidates
    }

    private func canDirectFlatMinorRootChallenge(
        challenger: ChordRecognitionCandidate,
        rescuedCandidate: ChordRecognitionCandidate
    ) -> Bool {
        switch rescuedCandidate.match.displayText {
        case "Ab-":
            return ["Cb-", "Eb-", "Gb-"].contains(challenger.match.displayText)
                && challenger.confidence >= 0.875
        case "Bb-":
            return challenger.match.displayText == "Db-"
                && challenger.confidence >= 0.895
        default:
            return false
        }
    }

    private func flatMinorDirectRootChallengeGap(
        challenger: ChordRecognitionCandidate,
        rescuedCandidate: ChordRecognitionCandidate
    ) -> Double {
        if challenger.method == .confirmedExample || challenger.method == .confirmedBoundary {
            return 0.13
        }

        switch rescuedCandidate.match.displayText {
        case "Ab-":
            return 0.12
        case "Bb-":
            return 0.10
        default:
            return 0
        }
    }

    private func canResolveBFlatMinorCloseRace(
        competitor: ChordRecognitionCandidate,
        bFlatMinorCandidate: ChordRecognitionCandidate,
        closeRaceSymbols: Set<String>,
        maximumGap: Double
    ) -> Bool {
        let gap = competitor.confidence - bFlatMinorCandidate.confidence
        guard closeRaceSymbols.contains(competitor.match.displayText),
              gap >= 0,
              gap <= maximumGap else {
            return false
        }

        if ["G-", "Gb", "Gb-"].contains(competitor.match.displayText) {
            return bFlatMinorCandidate.confidence >= 0.82
        }

        return true
    }

    private func minorNaturalRootCloseRaceResolvedCandidates(
        _ candidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        guard candidates.count > 1,
              let bestCandidate = candidates.max(by: { $0.confidence < $1.confidence }),
              bestCandidate.isNaturalMinor,
              (bestCandidate.method == .confirmedExample || bestCandidate.method == .confirmedBoundary),
              bestCandidate.confidence < 0.97,
              let bestIndex = candidates.firstIndex(where: {
                  $0.match.displayText == bestCandidate.match.displayText
              }) else {
            return candidates
        }

        guard let rootBackedChallenger = candidates
            .filter({
                $0.match.displayText != bestCandidate.match.displayText
                    && $0.isNaturalMinor
                    && $0.method == .strokeRootShape
                    && $0.hasMinorSuffixShapeSupport
                    && !$0.hasLearnedCorrectionPenalty
                    && !$0.wasResolvedAwayFromRootCandidate
                    && $0.confidence >= 0.70
            })
            .max(by: { $0.confidence < $1.confidence }) else {
            return candidates
        }

        let gap = bestCandidate.confidence - rootBackedChallenger.confidence
        guard gap >= 0,
              gap <= 0.065 else {
            return candidates
        }

        var resolvedCandidates = candidates
        resolvedCandidates[bestIndex].confidence = max(0.50, rootBackedChallenger.confidence - 0.001)
        resolvedCandidates[bestIndex].debugSummary += " minorNaturalRootCloseRacePenalty=\(String(format: "%.3f", gap))"

        if let challengerIndex = resolvedCandidates.firstIndex(where: {
            $0.match.displayText == rootBackedChallenger.match.displayText
        }) {
            resolvedCandidates[challengerIndex].debugSummary += " minorNaturalRootCloseRacePreferred=\(bestCandidate.match.displayText) gap=\(String(format: "%.3f", gap))"
        }

        return resolvedCandidates
    }

    var bestCandidate: ChordRecognitionCandidate? {
        strongestCandidatesBySymbol.first
    }

    var bestMatch: ChordRecognitionMatch? {
        bestCandidate?.match
    }

    var runnerUpCandidate: ChordRecognitionCandidate? {
        let rankedCandidates = strongestCandidatesBySymbol
        guard rankedCandidates.count > 1 else {
            return nil
        }

        return rankedCandidates[1]
    }

    var bestConfidenceMargin: Double {
        guard let bestCandidate else {
            return 0
        }

        guard let runnerUpCandidate else {
            return bestCandidate.confidence
        }

        return bestCandidate.confidence - runnerUpCandidate.confidence
    }

    var shouldAutoAcceptBestCandidate: Bool {
        guard let bestCandidate else {
            return false
        }

        switch bestCandidate.method {
        case .confirmedExample:
            if bestCandidate.isNaturalMinor,
               bestCandidate.hasMinorNaturalRootCloseRaceMarker {
                return false
            }

            if bestCandidate.confidence >= 0.995 {
                return true
            }

            if bestCandidate.isNaturalMinor {
                return bestCandidate.confidence >= 0.92 && bestConfidenceMargin >= 0.08
            }

            if bestCandidate.confidence >= 0.97 {
                return bestConfidenceMargin >= 0.001
            }

            return bestCandidate.confidence >= 0.88 && bestConfidenceMargin >= 0.06
        case .confirmedBoundary:
            return bestCandidate.confidence >= 0.90 && bestConfidenceMargin >= 0.08
        case .textOCRExact:
            return bestCandidate.confidence >= 0.90
        case .strokeRootShape:
            if bestCandidate.isNaturalMinor,
               bestCandidate.hasMinorNaturalRootCloseRaceMarker {
                return false
            }

            guard visualDecisionMargin(for: bestCandidate) >= visualAutoAcceptMargin(for: bestCandidate.match.displayText) else {
                return false
            }

            if bestCandidate.confidence >= 0.76 {
                return true
            }

            return bestCandidate.confidence >= 0.68 && bestConfidenceMargin >= 0.14
        case .rasterTemplate:
            return bestCandidate.confidence >= 0.84
                && hasStrokeAgreement(for: bestCandidate.match.displayText)
                && bestConfidenceMargin >= 0.08
        }
    }

    func hasStrokeAgreement(for displayText: String) -> Bool {
        candidates.contains { candidate in
            candidate.match.displayText == displayText
                && candidate.method == .strokeRootShape
                && candidate.confidence >= 0.62
        }
    }

    var shouldOfferBestCandidateConfirmation: Bool {
        guard let bestCandidate else {
            return false
        }

        return bestCandidate.confidence >= 0.55
    }

    var debugSummary: String {
        guard !candidates.isEmpty else {
            return "no candidates"
        }

        return candidates
            .sorted { $0.confidence > $1.confidence }
            .map { candidate in
                "\(candidate.method.rawValue):\(candidate.match.displayText)@\(String(format: "%.2f", candidate.confidence))"
            }
            .joined(separator: " | ")
    }

    private func methodPriority(_ method: ChordRecognitionMethod) -> Int {
        switch method {
        case .confirmedExample:
            return 5
        case .confirmedBoundary:
            return 4
        case .textOCRExact:
            return 4
        case .strokeRootShape:
            return 3
        case .rasterTemplate:
            return 2
        }
    }

    private func visualAutoAcceptMargin(for displayText: String) -> Double {
        switch displayText {
        case "B":
            return 0.10
        case "A", "D", "F", "G":
            return 0.09
        case "E":
            return 0.07
        default:
            if let match = ChordRecognitionCompendium.match(displayText),
               match.symbol.accidental != .natural,
               match.symbol.quality.isEmpty {
                return 0.12
            }

            return 0.08
        }
    }

    private func visualDecisionMargin(for bestCandidate: ChordRecognitionCandidate) -> Double {
        guard bestCandidate.method == .strokeRootShape else {
            return bestConfidenceMargin
        }

        let strongestCompetingStrokeConfidence = candidates
            .filter { candidate in
                candidate.method == .strokeRootShape
                    && candidate.match.displayText != bestCandidate.match.displayText
            }
            .map(\.confidence)
            .max()

        guard let strongestCompetingStrokeConfidence else {
            return max(bestConfidenceMargin, bestCandidate.confidence)
        }

        return max(bestConfidenceMargin, bestCandidate.confidence - strongestCompetingStrokeConfidence)
    }

    private func closeRaceResolvedCandidates(
        from evaluations: [SymbolCandidateEvaluation]
    ) -> [ChordRecognitionCandidate] {
        guard evaluations.count > 1 else {
            return evaluations.map(\.candidate)
        }

        var resolvedEvaluations = evaluations
        let rankedEvaluations = evaluations.sorted { lhs, rhs in
            if abs(lhs.candidate.confidence - rhs.candidate.confidence) > 0.0001 {
                return lhs.candidate.confidence > rhs.candidate.confidence
            }

            if abs(lhs.agreementBoost - rhs.agreementBoost) > 0.0001 {
                return lhs.agreementBoost > rhs.agreementBoost
            }

            return methodPriority(lhs.candidate.method) > methodPriority(rhs.candidate.method)
        }
        guard let bestEvaluation = rankedEvaluations.first,
              bestEvaluation.candidate.method != .textOCRExact,
              let bestIndex = resolvedEvaluations.firstIndex(where: {
                  $0.candidate.match.displayText == bestEvaluation.candidate.match.displayText
              }) else {
            return resolvedEvaluations.map(\.candidate)
        }

        guard let confirmedChallenger = evaluations
            .compactMap({ evaluation -> (evaluation: SymbolCandidateEvaluation, candidate: ChordRecognitionCandidate)? in
                guard evaluation.candidate.match.displayText != bestEvaluation.candidate.match.displayText,
                      let confirmedCandidate = evaluation.strongestConfirmedExample else {
                    return nil
                }

                return (evaluation, confirmedCandidate)
            })
            .max(by: { lhs, rhs in
                lhs.candidate.confidence < rhs.candidate.confidence
            }) else {
            return resolvedEvaluations.map(\.candidate)
        }

        let boostedGap = bestEvaluation.candidate.confidence - confirmedChallenger.candidate.confidence
        guard boostedGap >= 0, boostedGap <= 0.075 else {
            return resolvedEvaluations.map(\.candidate)
        }

        let bestConfirmedConfidence = bestEvaluation.strongestConfirmedExample?.confidence ?? bestEvaluation.rawConfidence
        let confirmedChallengerHasRawLead = confirmedChallenger.candidate.confidence > bestConfirmedConfidence + 0.004
        let penalizedHeuristicBest = bestEvaluation.hasPenalizedHeuristicSupport
            && (bestEvaluation.candidate.method == .strokeRootShape || bestEvaluation.candidate.method == .rasterTemplate)
        let penalizedHeuristicSupport = bestEvaluation.hasPenalizedHeuristicSupport && confirmedChallengerHasRawLead
        let agreementFlip = bestEvaluation.agreementBoost > 0
            && confirmedChallengerHasRawLead
            && boostedGap <= 0.050

        guard penalizedHeuristicBest || penalizedHeuristicSupport || agreementFlip else {
            return resolvedEvaluations.map(\.candidate)
        }

        resolvedEvaluations[bestIndex].candidate.confidence = max(
            0.50,
            confirmedChallenger.candidate.confidence - 0.001
        )
        resolvedEvaluations[bestIndex].candidate.debugSummary += " closeRaceResolvedToConfirmed=\(confirmedChallenger.candidate.match.displayText) gap=\(String(format: "%.3f", boostedGap))"
        return resolvedEvaluations.map(\.candidate)
    }

    private struct SymbolCandidateEvaluation {
        var candidate: ChordRecognitionCandidate
        var rawConfidence: Double
        var agreementBoost: Double
        var strongestConfirmedExample: ChordRecognitionCandidate?
        var hasPenalizedHeuristicSupport: Bool
    }
}

typealias BasicMajorChordRecognitionReport = ChordRecognitionReport

extension ChordRecognitionCandidate {
    var structuralEvidence: ChordRecognitionStructuralEvidence {
        var evidence = ChordRecognitionStructuralEvidence()

        switch method {
        case .textOCRExact:
            evidence = evidence.adding(.root, source: .text)
            if match.symbol.accidental != .natural {
                evidence = evidence.adding(.accidental, source: .text)
            }
            if match.symbol.quality == "-" {
                evidence = evidence.adding(.quality, source: .text)
            }
        case .confirmedExample:
            evidence = evidence.adding(.root, source: .learnedExample)
        case .confirmedBoundary:
            evidence = evidence.adding(.root, source: .learnedBoundary)
        case .strokeRootShape:
            evidence = evidence.adding(.root, source: .visualRoot)
        case .rasterTemplate:
            evidence = evidence.adding(.root, source: .rasterTemplate)
        }

        if hasRootShapeSupport {
            evidence = evidence.adding(.root, source: .visualRoot)
        }

        if hasAccidentalShapeSupport {
            evidence = evidence.adding(.accidental, source: .visualAccidental)
        }

        if hasMinorSuffixShapeSupport {
            evidence = evidence.adding(.quality, source: .visualQuality)
        }

        return evidence
    }
}

private extension ChordRecognitionCandidate {
    var hasLearnedCorrectionPenalty: Bool {
        debugSummary.contains("learnedCorrectionPenalty=")
    }

    var isNaturalMinor: Bool {
        match.symbol.quality == "-" && match.symbol.accidental == .natural
    }

    var isFlatMinor: Bool {
        match.symbol.quality == "-" && match.symbol.accidental == .flat
    }

    var isAccidentalOrMinor: Bool {
        match.symbol.accidental != .natural || match.symbol.quality == "-"
    }

    var hasMinorSuffixShapeSupport: Bool {
        debugSummary.contains("minorSuffixShape")
    }

    var hasRootShapeSupport: Bool {
        method == .strokeRootShape
            || debugSummary.contains("rootMethod=strokeRootShape")
    }

    var hasAccidentalShapeSupport: Bool {
        debugSummary.contains("rootAccidentalShape")
            || debugSummary.contains("\(match.symbol.root.rawValue)\(match.symbol.accidental.rawValue) rootAccidentalShape")
    }

    var hasMinorNaturalRootCloseRaceMarker: Bool {
        debugSummary.contains("minorNaturalRootCloseRace")
    }

    var wasResolvedAwayFromRootCandidate: Bool {
        debugSummary.contains("closeRaceResolvedToConfirmed=")
    }

    var hasFlatMinorSecondaryBRootRescue: Bool {
        debugSummary.contains("flatMinorSecondaryBRootRescue")
    }

    var hasFlatMinorSecondaryRootRescue: Bool {
        debugSummary.contains("flatMinorSecondaryARootRescue")
            || debugSummary.contains("flatMinorSecondaryBRootRescue")
    }

    var hasDirectFlatRootSupport: Bool {
        guard isFlatMinor else {
            return false
        }

        return debugSummary.contains("\(match.symbol.root.rawValue)+b rootAccidentalShape")
    }

    var hasBFlatMinorCloseRacePenalty: Bool {
        debugSummary.contains("bbFlatMinorCloseRacePenalty=")
    }

    var hasBFlatMinorShapeSupport: Bool {
        match.displayText == "Bb-"
            && hasMinorSuffixShapeSupport
            && debugSummary.contains("B+b rootAccidentalShape")
            && (bFlatMinorRootStrokeCount ?? Int.max) <= 2
    }

    var bFlatMinorRootStrokeCount: Int? {
        guard let range = debugSummary.range(of: "rootStrokes=") else {
            return nil
        }

        let suffix = debugSummary[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        guard !digits.isEmpty else {
            return nil
        }

        return Int(digits)
    }
}

struct ChordRecognitionInkSample {
    var strokes: [[CGPoint]]

    init(strokes: [[CGPoint]]) {
        self.strokes = strokes
            .map { stroke in stroke.filter { point in point.x.isFinite && point.y.isFinite } }
            .filter { !$0.isEmpty }
    }

    var allPoints: [CGPoint] {
        strokes.flatMap { $0 }
    }

    var bounds: CGRect? {
        let points = allPoints
        guard let firstPoint = points.first else {
            return nil
        }

        return points.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialResult, point in
            partialResult.union(CGRect(origin: point, size: .zero))
        }
    }

    var normalizedPoints: [CGPoint] {
        guard let bounds,
              bounds.width > 0.5,
              bounds.height > 0.5 else {
            return []
        }

        return allPoints.map { point in
            CGPoint(
                x: (point.x - bounds.minX) / bounds.width,
                y: (point.y - bounds.minY) / bounds.height
            )
        }
    }

    var normalizedStrokes: [[CGPoint]] {
        guard let bounds,
              bounds.width > 0.5,
              bounds.height > 0.5 else {
            return []
        }

        return strokes.map { stroke in
            stroke.map { point in
                CGPoint(
                    x: (point.x - bounds.minX) / bounds.width,
                    y: (point.y - bounds.minY) / bounds.height
                )
            }
        }
    }

    func excludingStrokeIndices(_ excludedIndices: Set<Int>) -> ChordRecognitionInkSample? {
        let keptStrokes = strokes.enumerated().compactMap { index, stroke in
            excludedIndices.contains(index) ? nil : stroke
        }
        let sample = ChordRecognitionInkSample(strokes: keptStrokes)
        return sample.strokes.isEmpty ? nil : sample
    }

    func sampledNormalizedStrokes(maxPointsPerStroke: Int = 48) -> [[CGPoint]] {
        normalizedStrokes.map { stroke in
            guard stroke.count > maxPointsPerStroke,
                  maxPointsPerStroke > 1 else {
                return stroke
            }

            return (0..<maxPointsPerStroke).map { index in
                let sourceIndex = Int(
                    (Double(index) / Double(maxPointsPerStroke - 1)) * Double(stroke.count - 1)
                )
                return stroke[sourceIndex]
            }
        }
    }
}

typealias BasicMajorChordInkSample = ChordRecognitionInkSample

#if canImport(PencilKit)
extension ChordRecognitionInkSample {
    init?(drawing: PKDrawing, localFrame: CGRect) {
        let searchFrame = localFrame.insetBy(dx: -4, dy: -4)
        let pointStrokes = drawing.strokes.compactMap { stroke -> [CGPoint]? in
            guard searchFrame.intersects(stroke.renderBounds) else {
                return nil
            }

            let points = Array(stroke.path).map(\.location)
            return points.isEmpty ? nil : points
        }

        self.init(strokes: pointStrokes)
        guard !strokes.isEmpty else {
            return nil
        }
    }
}
#endif

enum ChordSymbolRecognizer {
    static func evaluate(
        textCandidates: [String],
        inkSample: ChordRecognitionInkSample?,
        confirmedExamples: [ChordRecognitionLearningExample] = []
    ) -> ChordRecognitionReport {
        ChordRecognitionPipeline(
            textCandidates: textCandidates,
            inkSample: inkSample,
            confirmedExamples: confirmedExamples
        )
        .evaluate()
    }
}

enum BasicMajorChordRecognizer {
    static func evaluate(
        textCandidates: [String],
        inkSample: ChordRecognitionInkSample?,
        confirmedExamples: [ChordRecognitionLearningExample] = []
    ) -> ChordRecognitionReport {
        ChordSymbolRecognizer.evaluate(
            textCandidates: textCandidates,
            inkSample: inkSample,
            confirmedExamples: confirmedExamples
        )
    }
}

private struct ChordRecognitionPipeline {
    var textCandidates: [String]
    var inkSample: ChordRecognitionInkSample?
    var confirmedExamples: [ChordRecognitionLearningExample]

    func evaluate() -> ChordRecognitionReport {
        var candidates = textRecognitionCandidates()
        guard let inkSample else {
            return ChordRecognitionReport(candidates: candidates)
        }

        let minorCandidates = minorQualityCandidates(from: inkSample)
        candidates.append(contentsOf: minorCandidates)

        let accidentalCandidates = accidentalRootCandidates(from: inkSample)
        if accidentalCandidates.isEmpty {
            candidates.append(contentsOf: naturalRootCandidates(from: inkSample))
            candidates = applyHeuristicCorrectionPressure(to: candidates, from: inkSample)
        } else {
            candidates = candidates.map(candidateWithAccidentalContextPenalty)
            candidates.append(contentsOf: accidentalCandidates)
        }

        candidates = applyMinorContextPenalty(
            to: candidates,
            minorCandidates: minorCandidates
        )
        candidates = applyFinalCorrectionPressure(to: candidates, from: inkSample)

        return ChordRecognitionReport(candidates: candidates)
    }

    private func textRecognitionCandidates() -> [ChordRecognitionCandidate] {
        textCandidates.compactMap { textCandidate in
            guard let match = ChordRecognitionCompendium.match(textCandidate) else {
                return nil
            }

            return ChordRecognitionCandidate(
                method: .textOCRExact,
                match: match,
                confidence: 0.94,
                debugSummary: "Vision text candidate: \(textCandidate)"
            )
        }
    }

    private func naturalRootCandidates(
        from inkSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        let learnedNaturalCandidates = ConfirmedChordExampleClassifier.candidates(
            from: inkSample,
            confirmedExamples: confirmedExamples
        )
        .filter {
            $0.match.symbol.accidental == .natural
                && $0.match.symbol.quality.isEmpty
        }

        return learnedNaturalCandidates
            + StrokeRootShapeChordClassifier.candidates(from: inkSample)
            + RasterTemplateChordClassifier.candidates(from: inkSample)
    }

    private func accidentalRootCandidates(
        from inkSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        RootAccidentalShapeChordClassifier.candidates(
            from: inkSample,
            confirmedExamples: confirmedExamples
        )
    }

    private func minorQualityCandidates(
        from inkSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        MinorQualitySuffixChordClassifier.candidates(
            from: inkSample,
            confirmedExamples: confirmedExamples
        )
    }

    private func applyHeuristicCorrectionPressure(
        to candidates: [ChordRecognitionCandidate],
        from inkSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        ConfirmedChordCorrectionPenalty.adjustedCandidates(
            candidates,
            from: inkSample,
            confirmedExamples: confirmedExamples
        )
    }

    private func applyFinalCorrectionPressure(
        to candidates: [ChordRecognitionCandidate],
        from inkSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        ConfirmedChordCorrectionPenalty.adjustedFinalCandidates(
            candidates,
            from: inkSample,
            confirmedExamples: confirmedExamples
        )
    }

    private func applyMinorContextPenalty(
        to candidates: [ChordRecognitionCandidate],
        minorCandidates: [ChordRecognitionCandidate]
    ) -> [ChordRecognitionCandidate] {
        guard !minorCandidates.isEmpty else {
            return candidates
        }

        return candidates.map {
            minorContextPenalizedCandidate($0, minorCandidates: minorCandidates)
        }
    }

    private func minorContextPenalizedCandidate(
        _ candidate: ChordRecognitionCandidate,
        minorCandidates: [ChordRecognitionCandidate]
    ) -> ChordRecognitionCandidate {
        guard candidate.match.symbol.quality.isEmpty else {
            return candidate
        }

        let matchingMinorCandidateExists = minorCandidates.contains { minorCandidate in
            minorCandidate.match.symbol.root == candidate.match.symbol.root
                && minorCandidate.match.symbol.accidental == candidate.match.symbol.accidental
                && minorCandidate.match.symbol.quality == "-"
        }

        var adjustedCandidate = candidate
        let penalty: Double
        switch candidate.method {
        case .textOCRExact:
            penalty = matchingMinorCandidateExists ? 0.16 : 0.10
        case .confirmedExample, .confirmedBoundary:
            penalty = matchingMinorCandidateExists ? 0.15 : 0.08
        case .strokeRootShape, .rasterTemplate:
            penalty = matchingMinorCandidateExists ? 0.20 : 0.13
        }
        adjustedCandidate.confidence = max(0.50, candidate.confidence - penalty)
        adjustedCandidate.debugSummary += " minorSuffixContextPenalty=\(String(format: "%.2f", penalty))"
        return adjustedCandidate
    }

    private func candidateWithAccidentalContextPenalty(
        _ candidate: ChordRecognitionCandidate
    ) -> ChordRecognitionCandidate {
        guard candidate.match.symbol.accidental == .natural else {
            return candidate
        }

        var adjustedCandidate = candidate
        let penalty: Double = candidate.method == .textOCRExact ? 0.18 : 0.14
        adjustedCandidate.confidence = max(0.50, candidate.confidence - penalty)
        adjustedCandidate.debugSummary += " accidentalContextPenalty=\(String(format: "%.2f", penalty))"
        return adjustedCandidate
    }
}

private enum ConfirmedChordExampleClassifier {
    private static let minimumBestSimilarity = 0.50
    private static let minimumFamilyScore = 0.52

    static func candidates(
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        guard !confirmedExamples.isEmpty else {
            return []
        }

        let inputInk = ChordRecognitionLearningInk(sample: sample)
        let scoredExamples = confirmedExamples.map { example in
            (example: example, similarity: inputInk.similarity(to: example.ink))
        }
        let boundaryCandidates = ConfirmedChordBoundaryClassifier.candidates(
            from: sample,
            confirmedExamples: confirmedExamples
        )

        let strongestExamplesBySymbol = Dictionary(grouping: scoredExamples) { scoredExample in
            scoredExample.example.displayText
        }

        return (strongestExamplesBySymbol.values.compactMap { symbolExamples in
            let rankedExamples = symbolExamples.sorted { $0.similarity > $1.similarity }
            guard let strongest = rankedExamples.first,
                  let match = ChordRecognitionCompendium.match(strongest.example.displayText) else {
                return nil
            }

            let topSimilarities = rankedExamples.prefix(3).map(\.similarity)
            let topAverage = topSimilarities.reduce(0, +) / Double(max(1, topSimilarities.count))
            let supportWeight = rankedExamples
                .filter { $0.similarity >= 0.48 }
                .reduce(0.0) { partialResult, scoredExample in
                    partialResult + scoredExample.example.effectiveWeight
                }
            let supportCount = Int(supportWeight.rounded(.down))
            let weightedTopAverage = weightedAverage(for: rankedExamples.prefix(3))
            let supportBonus = min(0.09, max(0, supportWeight - 1) * 0.018)
            let familyScore = strongest.similarity * 0.67 + weightedTopAverage * 0.27 + supportBonus

            guard strongest.similarity >= minimumBestSimilarity || familyScore >= minimumFamilyScore else {
                return nil
            }

            let rawConfidence = confidence(
                bestSimilarity: strongest.similarity,
                familyScore: familyScore,
                supportCount: supportCount
            )
            let negativeSimilarity = negativeSimilarity(
                for: strongest.example.displayText,
                scoredExamples: scoredExamples
            )
            let negativePenalty = confirmedExampleNegativePenalty(
                negativeSimilarity: negativeSimilarity,
                positiveSimilarity: strongest.similarity
            )
            let confidence = max(0.50, rawConfidence - negativePenalty)
            let negativeSummary = negativePenalty > 0
                ? " confirmedNegativePenalty=\(String(format: "%.2f", negativePenalty)) negativeSimilarity=\(String(format: "%.2f", negativeSimilarity))"
                : ""
            return ChordRecognitionCandidate(
                method: .confirmedExample,
                match: ChordRecognitionMatch(rawInput: strongest.example.rawInput, symbol: match.symbol),
                confidence: confidence,
                debugSummary: "confirmed family \(strongest.example.displayText) best=\(String(format: "%.2f", strongest.similarity)) avg=\(String(format: "%.2f", topAverage)) weightedAvg=\(String(format: "%.2f", weightedTopAverage)) support=\(String(format: "%.1f", supportWeight)) id=\(strongest.example.id.uuidString)\(negativeSummary)"
            )
        } + boundaryCandidates)
        .sorted { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.0001 {
                return lhs.confidence > rhs.confidence
            }

            return lhs.match.displayText < rhs.match.displayText
        }
    }

    private static func confidence(
        bestSimilarity: Double,
        familyScore: Double,
        supportCount: Int
    ) -> Double {
        if bestSimilarity >= 0.96 {
            return 1
        }

        if bestSimilarity >= 0.82 {
            return max(0.92, min(0.97, 0.50 + familyScore * 0.48))
        }

        if bestSimilarity >= 0.70 {
            return max(0.87, min(0.93, 0.48 + familyScore * 0.48))
        }

        let supportConfidence = min(0.04, Double(max(0, supportCount - 1)) * 0.01)
        return min(0.86, 0.46 + familyScore * 0.50 + supportConfidence)
    }

    private static func confirmedExampleNegativePenalty(
        negativeSimilarity: Double,
        positiveSimilarity: Double
    ) -> Double {
        guard negativeSimilarity >= 0.52 else {
            return 0
        }

        let pressure = max(0, negativeSimilarity - positiveSimilarity + 0.18)
        guard pressure >= 0.04 else {
            return 0
        }

        return min(0.24, pressure * 0.80)
    }

    private static func negativeSimilarity(
        for displayText: String,
        scoredExamples: [(example: ChordRecognitionLearningExample, similarity: Double)]
    ) -> Double {
        let directFalsePositives = scoredExamples.filter { scoredExample in
            scoredExample.example.wasCorrection == true
                && scoredExample.example.displayText != displayText
                && scoredExample.example.suggestedDisplayText == displayText
        }

        let competitiveFalsePositives = scoredExamples.filter { scoredExample in
            scoredExample.example.wasCorrection == true
                && scoredExample.example.displayText != displayText
                && sourceSummary(scoredExample.example.sourceReportSummary, mentions: displayText)
        }

        return max(
            weightedTopSimilarity(for: directFalsePositives),
            weightedTopSimilarity(for: competitiveFalsePositives) * 0.65
        )
    }

    private static func sourceSummary(_ summary: String?, mentions displayText: String) -> Bool {
        guard let summary else {
            return false
        }

        return summary.contains("\(displayText)@")
    }

    private static func weightedAverage<S: Sequence>(
        for scoredExamples: S
    ) -> Double where S.Element == (example: ChordRecognitionLearningExample, similarity: Double) {
        let totals = scoredExamples.reduce(into: (weightedSimilarity: 0.0, weight: 0.0)) { partialResult, scoredExample in
            let weight = scoredExample.example.effectiveWeight
            partialResult.weightedSimilarity += scoredExample.similarity * weight
            partialResult.weight += weight
        }

        guard totals.weight > 0 else {
            return 0
        }

        return totals.weightedSimilarity / totals.weight
    }

    private static func weightedTopSimilarity<S: Sequence>(
        for scoredExamples: S
    ) -> Double where S.Element == (example: ChordRecognitionLearningExample, similarity: Double) {
        let topExamples = scoredExamples
            .sorted { $0.similarity > $1.similarity }
            .prefix(4)
        let totals = topExamples.reduce(into: (weightedSimilarity: 0.0, weight: 0.0)) { partialResult, scoredExample in
            partialResult.weightedSimilarity += scoredExample.similarity * scoredExample.example.effectiveWeight
            partialResult.weight += scoredExample.example.effectiveWeight
        }

        guard totals.weight > 0 else {
            return 0
        }

        return totals.weightedSimilarity / totals.weight
    }
}

private enum ConfirmedChordCorrectionPenalty {
    private enum PenaltyMode {
        case heuristicOnly
        case finalSymbol
    }

    static func adjustedCandidates(
        _ candidates: [ChordRecognitionCandidate],
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        adjustedCandidates(
            candidates,
            from: sample,
            confirmedExamples: confirmedExamples,
            mode: .heuristicOnly
        )
    }

    static func adjustedFinalCandidates(
        _ candidates: [ChordRecognitionCandidate],
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        adjustedCandidates(
            candidates,
            from: sample,
            confirmedExamples: confirmedExamples,
            mode: .finalSymbol
        )
    }

    private static func adjustedCandidates(
        _ candidates: [ChordRecognitionCandidate],
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample],
        mode: PenaltyMode
    ) -> [ChordRecognitionCandidate] {
        guard !confirmedExamples.isEmpty else {
            return candidates
        }

        let inputInk = ChordRecognitionLearningInk(sample: sample)

        return candidates.map { candidate in
            guard shouldApplyPenalty(to: candidate, mode: mode) else {
                return candidate
            }

            let symbol = candidate.match.displayText
            let falsePositiveExamples = confirmedExamples.filter { example in
                example.displayText != symbol
                    && example.suggestedDisplayText == symbol
            }
            let falsePositiveWeight = falsePositiveExamples.reduce(0.0) {
                $0 + $1.effectiveWeight
            }
            guard falsePositiveWeight >= minimumFalsePositiveWeight(for: candidate, mode: mode) else {
                return candidate
            }

            let positiveExamples = confirmedExamples.filter { $0.displayText == symbol }
            let negativeSimilarity = weightedTopSimilarity(
                inputInk: inputInk,
                examples: falsePositiveExamples
            )
            let positiveSimilarity = weightedTopSimilarity(
                inputInk: inputInk,
                examples: positiveExamples
            )
            guard negativeSimilarity >= minimumNegativeSimilarity(for: candidate, mode: mode) else {
                return candidate
            }

            let dominance = negativeSimilarity - positiveSimilarity
            let penaltyBase = max(0, dominance + dominanceTolerance(for: candidate, mode: mode))
            guard penaltyBase > 0.01 else {
                return candidate
            }

            let correctionPressure = min(
                maximumCorrectionPressure(for: candidate, mode: mode),
                falsePositiveWeight * 0.006
            )
            let penalty = min(
                maximumPenalty(for: candidate.method),
                penaltyBase * 0.70 + correctionPressure
            )
            guard penalty >= 0.025 else {
                return candidate
            }

            var adjustedCandidate = candidate
            adjustedCandidate.confidence = max(0.50, candidate.confidence - penalty)
            adjustedCandidate.debugSummary += " learnedCorrectionPenalty=\(String(format: "%.2f", penalty)) negativeSimilarity=\(String(format: "%.2f", negativeSimilarity)) positiveSimilarity=\(String(format: "%.2f", positiveSimilarity))"
            return adjustedCandidate
        }
    }

    private static func shouldApplyPenalty(
        to candidate: ChordRecognitionCandidate,
        mode: PenaltyMode
    ) -> Bool {
        switch candidate.method {
        case .strokeRootShape, .rasterTemplate, .textOCRExact:
            return true
        case .confirmedExample, .confirmedBoundary:
            return mode == .finalSymbol && candidate.isAccidentalOrMinor
        }
    }

    private static func minimumFalsePositiveWeight(
        for candidate: ChordRecognitionCandidate,
        mode: PenaltyMode
    ) -> Double {
        switch (mode, candidate.method) {
        case (.finalSymbol, .confirmedExample), (.finalSymbol, .confirmedBoundary):
            return 2.5
        default:
            return 2.0
        }
    }

    private static func minimumNegativeSimilarity(
        for candidate: ChordRecognitionCandidate,
        mode: PenaltyMode
    ) -> Double {
        switch (mode, candidate.method) {
        case (.finalSymbol, .confirmedExample), (.finalSymbol, .confirmedBoundary):
            return 0.58
        default:
            return 0.54
        }
    }

    private static func dominanceTolerance(
        for candidate: ChordRecognitionCandidate,
        mode: PenaltyMode
    ) -> Double {
        switch (mode, candidate.method) {
        case (.finalSymbol, .confirmedExample), (.finalSymbol, .confirmedBoundary):
            return 0.02
        default:
            return 0.05
        }
    }

    private static func maximumCorrectionPressure(
        for candidate: ChordRecognitionCandidate,
        mode: PenaltyMode
    ) -> Double {
        switch (mode, candidate.method) {
        case (.finalSymbol, .confirmedExample), (.finalSymbol, .confirmedBoundary):
            return 0.08
        default:
            return 0.06
        }
    }

    private static func maximumPenalty(for method: ChordRecognitionMethod) -> Double {
        switch method {
        case .strokeRootShape:
            return 0.18
        case .rasterTemplate:
            return 0.13
        case .textOCRExact:
            return 0.11
        case .confirmedExample:
            return 0.22
        case .confirmedBoundary:
            return 0.18
        }
    }

    private static func weightedTopSimilarity(
        inputInk: ChordRecognitionLearningInk,
        examples: [ChordRecognitionLearningExample]
    ) -> Double {
        let scoredExamples = examples
            .map { example in
                (similarity: inputInk.similarity(to: example.ink), weight: example.effectiveWeight)
            }
            .sorted { $0.similarity > $1.similarity }
            .prefix(4)

        let totals = scoredExamples.reduce(into: (score: 0.0, weight: 0.0)) { partialResult, scoredExample in
            partialResult.score += scoredExample.similarity * scoredExample.weight
            partialResult.weight += scoredExample.weight
        }

        guard totals.weight > 0 else {
            return 0
        }

        return totals.score / totals.weight
    }
}

private enum ConfirmedChordBoundaryClassifier {
    private static let gridSize = 16
    private static let minimumExamplesPerSymbol = 5
    private static let minimumAccuracy = 0.52
    private static let minimumOuterContainment = 0.56
    private static let minimumInnerHit = 0.16

    static func candidates(
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        let models = boundaryModels(from: confirmedExamples)
        guard !models.isEmpty else {
            return []
        }

        let inputCells = occupiedCells(from: sample, gridSize: gridSize)
        guard !inputCells.isEmpty else {
            return []
        }

        let scoredModels = models.map { model in
            (model: model, score: model.score(inputCells: inputCells, sample: sample))
        }

        return scoredModels.compactMap { scoredModel in
            let model = scoredModel.model
            let score = scoredModel.score
            let bestCompetingAccuracy = scoredModels
                .filter { $0.model.displayText != model.displayText }
                .map(\.score.accuracy)
                .max() ?? 0
            let separation = score.accuracy - bestCompetingAccuracy
            guard score.accuracy >= minimumAccuracy,
                  score.outerContainment >= minimumOuterContainment,
                  score.innerHit >= minimumInnerHit,
                  let match = ChordRecognitionCompendium.match(model.displayText) else {
                return nil
            }

            let supportBoost = min(0.03, Double(model.exampleCount - minimumExamplesPerSymbol) * 0.002)
            let separationBoost = max(0, separation) * 0.65
            let negativePenalty = score.correctedNegativeHit * 0.20 + score.competitiveNegativeHit * 0.08
            let confidence = min(
                0.89,
                max(
                    0.56,
                    0.50 + score.accuracy * 0.35 + separationBoost + supportBoost - negativePenalty
                )
            )

            return ChordRecognitionCandidate(
                method: .confirmedBoundary,
                match: ChordRecognitionMatch(rawInput: model.rawInput, symbol: match.symbol),
                confidence: confidence,
                debugSummary: "boundary \(model.displayText) accuracy=\(String(format: "%.0f", score.accuracy * 100))% innerHit=\(String(format: "%.0f", score.innerHit * 100))% outerContainment=\(String(format: "%.0f", score.outerContainment * 100))% negativeHit=\(String(format: "%.0f", score.correctedNegativeHit * 100))% separation=\(String(format: "%.0f", separation * 100))% examples=\(model.exampleCount)"
            )
        }
    }

    private static func boundaryModels(
        from confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ConfirmedChordBoundaryModel] {
        let groupedExamples = Dictionary(grouping: confirmedExamples, by: \.displayText)
        let initialModels: [ConfirmedChordBoundaryModel] = groupedExamples
            .values
            .compactMap { examples -> ConfirmedChordBoundaryModel? in
                guard examples.count >= minimumExamplesPerSymbol else {
                    return nil
                }

                return ConfirmedChordBoundaryModel(
                    examples: examples,
                    gridSize: gridSize
                )
            }

        return initialModels.map { model in
            var tunedModel = model
            tunedModel.applyNegativeEvidence(from: initialModels, confirmedExamples: confirmedExamples)
            return tunedModel
        }
    }

    fileprivate static func occupiedCells(
        from sample: ChordRecognitionInkSample,
        gridSize: Int
    ) -> Set<Int> {
        occupiedCells(
            from: sample.normalizedStrokes,
            gridSize: gridSize
        )
    }

    private static func occupiedCells(
        from normalizedStrokes: [[CGPoint]],
        gridSize: Int
    ) -> Set<Int> {
        var cells = Set<Int>()

        for stroke in normalizedStrokes {
            guard let firstPoint = stroke.first else {
                continue
            }

            cells.insert(cell(for: firstPoint, gridSize: gridSize))
            for segment in zip(stroke, stroke.dropFirst()) {
                let dx = segment.1.x - segment.0.x
                let dy = segment.1.y - segment.0.y
                let segmentLength = hypot(dx, dy)
                let steps = max(1, Int(ceil(segmentLength * CGFloat(gridSize) * 2)))
                for step in 0...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    cells.insert(
                        cell(
                            for: CGPoint(
                                x: segment.0.x + dx * t,
                                y: segment.0.y + dy * t
                            ),
                            gridSize: gridSize
                        )
                    )
                }
            }
        }

        return cells
    }

    private static func cell(for point: CGPoint, gridSize: Int) -> Int {
        let x = min(gridSize - 1, max(0, Int((point.x * CGFloat(gridSize)).rounded(.down))))
        let y = min(gridSize - 1, max(0, Int((point.y * CGFloat(gridSize)).rounded(.down))))
        return y * gridSize + x
    }

    fileprivate static func dilatedCells(_ cells: Set<Int>, gridSize: Int) -> Set<Int> {
        var dilated = cells

        for cell in cells {
            let x = cell % gridSize
            let y = cell / gridSize
            for dx in -1...1 {
                for dy in -1...1 {
                    let nextX = x + dx
                    let nextY = y + dy
                    guard nextX >= 0,
                          nextX < gridSize,
                          nextY >= 0,
                          nextY < gridSize else {
                        continue
                    }

                    dilated.insert(nextY * gridSize + nextX)
                }
            }
        }

        return dilated
    }
}

private struct ConfirmedChordBoundaryModel {
    var displayText: String
    var rawInput: String
    var exampleCount: Int
    var correctionCount: Int
    var densityByCell: [Int: Double]
    var outerCells: Set<Int>
    var innerCells: Set<Int>
    var ambiguousCells: Set<Int>
    var correctedNegativeCells: Set<Int> = []
    var competitiveNegativeCells: Set<Int> = []
    var averageAspectRatio: Double
    var gridSize: Int

    init?(
        examples: [ChordRecognitionLearningExample],
        gridSize: Int
    ) {
        guard let firstExample = examples.first else {
            return nil
        }

        self.displayText = firstExample.displayText
        self.rawInput = firstExample.rawInput
        self.exampleCount = examples.count
        self.correctionCount = examples.filter { $0.wasCorrection == true }.count
        self.gridSize = gridSize

        let totalWeight = examples.reduce(0.0) { $0 + $1.effectiveWeight }
        guard totalWeight > 0 else {
            return nil
        }

        var frequencyByCell: [Int: Double] = [:]
        var aspectTotal = 0.0
        var aspectWeight = 0.0

        for example in examples {
            let weight = example.effectiveWeight
            let cells = ConfirmedChordBoundaryClassifier.occupiedCells(
                from: example.ink.inkSample,
                gridSize: gridSize
            )
            for cell in cells {
                frequencyByCell[cell, default: 0] += weight
            }
            aspectTotal += example.ink.aspectRatio * weight
            aspectWeight += weight
        }

        let coreThreshold = max(2.0, totalWeight * 0.18)
        let outerThreshold = max(1.0, totalWeight * 0.035)
        let rawOuterCells = Set(frequencyByCell.compactMap { cell, frequency in
            frequency >= outerThreshold ? cell : nil
        })
        let rawInnerCells = Set(frequencyByCell.compactMap { cell, frequency in
                frequency >= coreThreshold ? cell : nil
        })

        guard !rawOuterCells.isEmpty,
              !rawInnerCells.isEmpty else {
            return nil
        }

        densityByCell = frequencyByCell.mapValues { $0 / totalWeight }
        outerCells = ConfirmedChordBoundaryClassifier.dilatedCells(rawOuterCells, gridSize: gridSize)
        innerCells = rawInnerCells
        ambiguousCells = outerCells.subtracting(innerCells)
        averageAspectRatio = aspectTotal / max(1, aspectWeight)
    }

    mutating func applyNegativeEvidence(
        from allModels: [ConfirmedChordBoundaryModel],
        confirmedExamples: [ChordRecognitionLearningExample]
    ) {
        correctedNegativeCells = correctedNegativeCells(from: confirmedExamples)
        competitiveNegativeCells = competitiveNegativeCells(from: allModels)
    }

    func score(
        inputCells: Set<Int>,
        sample: ChordRecognitionInkSample
    ) -> ConfirmedChordBoundaryScore {
        let innerHit = Double(inputCells.intersection(innerCells).count) / Double(max(1, innerCells.count))
        let innerPrecision = Double(inputCells.intersection(innerCells).count) / Double(max(1, inputCells.count))
        let outerContainment = Double(inputCells.intersection(outerCells).count) / Double(max(1, inputCells.count))
        let strayPenalty = Double(inputCells.subtracting(outerCells).count) / Double(max(1, inputCells.count))
        let ambiguousPenalty = Double(inputCells.intersection(ambiguousCells).count) / Double(max(1, inputCells.count))
        let correctedNegativeHit = Double(inputCells.intersection(correctedNegativeCells).count) / Double(max(1, inputCells.count))
        let competitiveNegativeHit = Double(inputCells.intersection(competitiveNegativeCells).count) / Double(max(1, inputCells.count))
        let aspectRatio: Double
        if let bounds = sample.bounds,
           bounds.height > 0 {
            aspectRatio = Double(bounds.width / bounds.height)
        } else {
            aspectRatio = averageAspectRatio
        }
        let aspectFit = max(0, 1 - abs(aspectRatio - averageAspectRatio) / 1.15)
        let accuracy = min(
            1,
            max(
                0,
                innerHit * 0.44
                    + innerPrecision * 0.10
                    + outerContainment * 0.30
                    + aspectFit * 0.15
                    - strayPenalty * 0.16
                    - ambiguousPenalty * 0.04
                    - correctedNegativeHit * 0.14
                    - competitiveNegativeHit * 0.06
            )
        )

        return ConfirmedChordBoundaryScore(
            accuracy: accuracy,
            innerHit: innerHit,
            outerContainment: outerContainment,
            contrast: max(0, outerContainment - strayPenalty - correctedNegativeHit),
            aspectFit: aspectFit,
            correctedNegativeHit: correctedNegativeHit,
            competitiveNegativeHit: competitiveNegativeHit
        )
    }

    private func correctedNegativeCells(
        from confirmedExamples: [ChordRecognitionLearningExample]
    ) -> Set<Int> {
        let negativeExamples = confirmedExamples.filter { example in
            example.displayText != displayText
                && example.suggestedDisplayText == displayText
        }
        guard !negativeExamples.isEmpty else {
            return []
        }

        var frequencyByCell: [Int: Double] = [:]
        let totalWeight = negativeExamples.reduce(0.0) { $0 + $1.effectiveWeight }
        guard totalWeight > 0 else {
            return []
        }

        for example in negativeExamples {
            let weight = example.effectiveWeight
            let cells = ConfirmedChordBoundaryClassifier.occupiedCells(
                from: example.ink.inkSample,
                gridSize: gridSize
            )
            for cell in cells {
                frequencyByCell[cell, default: 0] += weight
            }
        }

        return Set(frequencyByCell.compactMap { cell, frequency in
            let negativeDensity = frequency / totalWeight
            let ownDensity = densityByCell[cell, default: 0]
            return negativeDensity >= 0.15 && negativeDensity - ownDensity >= 0.06 ? cell : nil
        })
    }

    private func competitiveNegativeCells(
        from allModels: [ConfirmedChordBoundaryModel]
    ) -> Set<Int> {
        Set((0..<(gridSize * gridSize)).compactMap { cell in
            let ownDensity = densityByCell[cell, default: 0]
            let strongestCompetingDensity = allModels
                .filter { $0.displayText != displayText }
                .map { $0.densityByCell[cell, default: 0] }
                .max() ?? 0

            return strongestCompetingDensity >= 0.22
                && strongestCompetingDensity - ownDensity >= 0.12
                ? cell
                : nil
        })
    }
}

private struct ConfirmedChordBoundaryScore {
    var accuracy: Double
    var innerHit: Double
    var outerContainment: Double
    var contrast: Double
    var aspectFit: Double
    var correctedNegativeHit: Double
    var competitiveNegativeHit: Double
}

private enum MinorQualitySuffixChordClassifier {
    static func candidates(
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        guard let detection = minorSuffixDetection(in: sample),
              let rootSample = rootSample(from: sample, detection: detection) else {
            return []
        }

        let rootCandidates = strongestRootCandidates(
            from: rootSample,
            confirmedExamples: confirmedExamples
        )

        return rootCandidates.compactMap { rootCandidate in
            let minorDisplayText = "\(rootCandidate.match.symbol.root.rawValue)\(rootCandidate.match.symbol.accidental.rawValue)-"
            guard let minorMatch = ChordRecognitionCompendium.match(minorDisplayText) else {
                return nil
            }

            let confidence = min(
                0.985,
                max(
                    0.68,
                    rootCandidate.confidence * rootConfidenceWeight(for: rootCandidate.method)
                        + detection.confidence * 0.24
                        + methodSupportBoost(for: rootCandidate.method)
                )
            )

            return ChordRecognitionCandidate(
                method: rootCandidate.method,
                match: minorMatch,
                confidence: confidence,
                debugSummary: "\(rootCandidate.match.displayText)- minorSuffixShape rootMethod=\(rootCandidate.method.rawValue) root=\(String(format: "%.2f", rootCandidate.confidence)) suffix=\(String(format: "%.2f", detection.confidence)) rootSummary={\(rootCandidate.debugSummary)} \(detection.debugSummary)"
            )
        }
    }

    private static func strongestRootCandidates(
        from rootSample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        let accidentalCandidates = RootAccidentalShapeChordClassifier.candidates(
            from: rootSample,
            confirmedExamples: confirmedExamples,
            maximumRootCandidates: 1,
            allowsFlatSecondaryBRoot: true
        )

        var candidates = ConfirmedChordExampleClassifier.candidates(
            from: rootSample,
            confirmedExamples: confirmedExamples
        ).filter { $0.match.symbol.accidental == .natural && $0.match.symbol.quality.isEmpty }
        candidates.append(contentsOf: StrokeRootShapeChordClassifier.candidates(from: rootSample))
        candidates.append(contentsOf: RasterTemplateChordClassifier.candidates(from: rootSample))
        candidates = ConfirmedChordCorrectionPenalty.adjustedCandidates(
            candidates,
            from: rootSample,
            confirmedExamples: confirmedExamples
        )
        candidates.append(contentsOf: accidentalCandidates)

        return Array(ChordRecognitionReport(candidates: candidates).strongestCandidatesBySymbol.prefix(8))
    }

    private static func rootSample(
        from sample: ChordRecognitionInkSample,
        detection: MinorSuffixDetection
    ) -> ChordRecognitionInkSample? {
        if detection.prefersLeftRegionRoot,
           let sampleBounds = sample.bounds {
            let cutoffX = sampleBounds.minX + sampleBounds.width * max(0, detection.bounds.minX - 0.035)
            let leftStrokes = sample.strokes.filter { stroke in
                guard let bounds = absoluteBounds(for: stroke) else {
                    return false
                }

                return bounds.maxX <= cutoffX
                    || bounds.midX <= cutoffX - sampleBounds.width * 0.04
            }

            if !leftStrokes.isEmpty {
                return ChordRecognitionInkSample(strokes: leftStrokes)
            }
        }

        return sample.excludingStrokeIndices(detection.strokeIndices)
    }

    private static func minorSuffixDetection(in sample: ChordRecognitionInkSample) -> MinorSuffixDetection? {
        guard let sampleBounds = sample.bounds,
              sample.strokes.count >= 2,
              sampleBounds.width > 14,
              sampleBounds.height > 8 else {
            return nil
        }

        let observations = sample.strokes.enumerated().compactMap { index, stroke in
            QualityStrokeObservation(index: index, stroke: stroke, sampleBounds: sampleBounds)
        }
        if let dashDetection = dashSuffixDetection(in: observations) {
            return dashDetection
        }

        if let minWordDetection = minWordSuffixDetection(in: observations) {
            return minWordDetection
        }

        return compactLetterSuffixDetection(in: observations)
    }

    private static func dashSuffixDetection(in observations: [QualityStrokeObservation]) -> MinorSuffixDetection? {
        let dashCandidates = observations.filter { observation in
            observation.isMinorDashLike
                && observation.bounds.minX >= 0.38
        }

        for dash in dashCandidates.sorted(by: { dashSuffixPriority($0) > dashSuffixPriority($1) }) {
            if let detection = dashSuffixDetection(
                for: dash,
                in: observations,
                dashCandidates: dashCandidates
            ) {
                return detection
            }
        }

        return nil
    }

    private static func dashSuffixDetection(
        for dash: QualityStrokeObservation,
        in observations: [QualityStrokeObservation],
        dashCandidates: [QualityStrokeObservation]
    ) -> MinorSuffixDetection? {
        let rightSideVerticals = observations.filter { observation in
            observation.index != dash.index
                && observation.bounds.midX >= dash.bounds.minX - 0.12
                && observation.bounds.width <= 0.18
                && observation.bounds.height >= 0.22
        }
        let rightSideHorizontals = dashCandidates.filter { $0.index != dash.index && $0.bounds.midX >= dash.bounds.midX - 0.10 }
        let overlappingAccidentalVerticals = rightSideVerticals.filter { vertical in
            dash.bounds.minX <= vertical.bounds.maxX + 0.03
                && boundsAreVerticallyRelated(dash.bounds, vertical.bounds)
        }
        let nearbyAccidentalStructure = observations.filter { observation in
            observation.index != dash.index
                && observation.bounds.maxX >= dash.bounds.minX - 0.12
                && (observation.isMostlyHorizontal || (observation.bounds.width <= 0.20 && observation.bounds.height >= 0.20))
                && boundsAreVerticallyRelated(dash.bounds, observation.bounds)
        }
        let nearbyStructureMaxX = nearbyAccidentalStructure.map(\.bounds.maxX).max() ?? 0
        let verticallyRelatedRightSideVerticals = rightSideVerticals.filter {
            boundsAreVerticallyRelated(dash.bounds, $0.bounds)
        }
        let verticallyRelatedRightSideHorizontals = rightSideHorizontals.filter {
            boundsAreVerticallyRelated(dash.bounds, $0.bounds)
        }
        let lowDashTuckedUnderFlat = lowDashTuckedUnderFlat(
            dash,
            observations: observations
        )

        guard dash.bounds.midX >= 0.58,
              dash.bounds.maxX >= 0.66,
              dash.bounds.width <= 0.48,
              lowDashTuckedUnderFlat || overlappingAccidentalVerticals.count < 2,
              lowDashTuckedUnderFlat || !(nearbyAccidentalStructure.count >= 2 && dash.bounds.minX <= nearbyStructureMaxX + 0.03),
              !(verticallyRelatedRightSideVerticals.count >= 2 && dash.bounds.midX < 0.86),
              lowDashTuckedUnderFlat || !(verticallyRelatedRightSideHorizontals.count >= 1 && dash.bounds.midX < 0.88) else {
            return nil
        }

        var confidence = 0.0
        confidence += min(1, Double(dash.bounds.width) / 0.24) * 0.34
        confidence += (1 - min(1, Double(dash.bounds.height) / 0.18)) * 0.22
        confidence += score(Double(dash.bounds.midX), target: 0.80, tolerance: 0.28) * 0.24
        confidence += score(Double(dash.bounds.midY), target: 0.70, tolerance: 0.46) * 0.10
        confidence += dash.bounds.maxX >= 0.72 ? 0.10 : 0

        guard confidence >= 0.54 else {
            return nil
        }

        return MinorSuffixDetection(
            strokeIndices: [dash.index],
            bounds: dash.bounds,
            confidence: min(0.93, max(0.72, confidence)),
            debugSummary: "minor dash suffix bounds=\(debugBounds(dash.bounds))",
            prefersLeftRegionRoot: false
        )
    }

    private static func lowDashTuckedUnderFlat(
        _ dash: QualityStrokeObservation,
        observations: [QualityStrokeObservation]
    ) -> Bool {
        guard dash.bounds.midY >= 0.62 else {
            return false
        }

        let nearbyFlatStemAbove = observations.contains { observation in
            observation.index != dash.index
                && observation.bounds.width <= 0.20
                && observation.bounds.height >= 0.16
                && observation.bounds.midX >= dash.bounds.minX - 0.18
                && observation.bounds.midX <= dash.bounds.midX + 0.08
                && observation.bounds.minY <= dash.bounds.minY
                && observation.bounds.maxY <= dash.bounds.midY + 0.08
        }
        let nearbyFlatBowlAbove = observations.contains { observation in
            observation.index != dash.index
                && observation.bounds.width >= 0.12
                && observation.bounds.height >= 0.12
                && observation.bounds.minX <= dash.bounds.maxX
                && observation.bounds.maxX >= dash.bounds.minX - 0.14
                && observation.bounds.midY <= dash.bounds.midY + 0.02
                && observation.bounds.maxY >= dash.bounds.minY - 0.18
        }
        let sharpLikeDoubleStemCluster = observations.filter { observation in
            observation.index != dash.index
                && observation.bounds.width <= 0.12
                && observation.bounds.height >= 0.24
                && observation.bounds.midX >= dash.bounds.minX - 0.16
        }.count >= 2

        return nearbyFlatStemAbove
            && nearbyFlatBowlAbove
            && !sharpLikeDoubleStemCluster
    }

    private static func dashSuffixPriority(_ observation: QualityStrokeObservation) -> Double {
        score(Double(observation.bounds.midY), target: 0.74, tolerance: 0.48) * 0.46
            + score(Double(observation.bounds.maxX), target: 0.94, tolerance: 0.34) * 0.24
            + min(1, Double(observation.bounds.width) / 0.24) * 0.20
            + (1 - min(1, Double(observation.bounds.height) / 0.16)) * 0.10
    }

    private static func minWordSuffixDetection(in observations: [QualityStrokeObservation]) -> MinorSuffixDetection? {
        let rightSideStrokes = observations.filter { observation in
            observation.bounds.midX >= 0.42
                && observation.bounds.maxX >= 0.52
                && observation.bounds.height >= 0.03
                && observation.bounds.height <= 0.88
                && observation.bounds.width <= 0.42
        }
        guard rightSideStrokes.count >= 3,
              rightSideStrokes.count <= 8 else {
            return nil
        }

        let groupBounds = unionBounds(for: rightSideStrokes)
        let suffixPoints = rightSideStrokes.flatMap(\.points)
        let verticalStrokeCount = rightSideStrokes.filter { observation in
            observation.bounds.height >= 0.18
                && observation.bounds.width <= 0.34
        }.count
        let lowerStrokeCount = rightSideStrokes.filter { observation in
            observation.bounds.maxY >= 0.54
                && observation.bounds.height >= 0.18
        }.count
        let shortMarkCount = rightSideStrokes.filter { observation in
            observation.bounds.height <= 0.16
                && observation.bounds.width <= 0.34
        }.count
        let absoluteLowerCoverage = fraction(of: suffixPoints) { $0.y >= 0.54 }
        let lowerCoverage = fraction(of: suffixPoints) { $0.y >= groupBounds.minY + groupBounds.height * 0.50 }
        let upperCoverage = fraction(of: suffixPoints) { $0.y <= groupBounds.minY + groupBounds.height * 0.35 }
        let rightEdgeCoverage = fraction(of: suffixPoints) { $0.x >= groupBounds.minX + groupBounds.width * 0.72 }
        let middleStrokeCoverage = fraction(of: suffixPoints) { point in
            (groupBounds.minX + groupBounds.width * 0.18...groupBounds.minX + groupBounds.width * 0.70).contains(point.x)
        }
        let aspectRatio = Double(groupBounds.width / max(0.0001, groupBounds.height))
        let sharpLikeCluster = groupBounds.maxY <= 0.52
            && absoluteLowerCoverage < 0.14
            && verticalStrokeCount >= 2

        var confidence = 0.0
        confidence += min(1, Double(verticalStrokeCount) / 3) * 0.25
        confidence += min(1, Double(shortMarkCount) / 1) * 0.08
        confidence += min(1, absoluteLowerCoverage / 0.34) * 0.18
        confidence += min(1, lowerCoverage / 0.34) * 0.14
        confidence += min(1, upperCoverage / 0.08) * 0.10
        confidence += min(1, rightEdgeCoverage / 0.18) * 0.09
        confidence += min(1, middleStrokeCoverage / 0.32) * 0.08
        confidence += score(aspectRatio, target: 0.78, tolerance: 0.70) * 0.08

        guard groupBounds.minX >= 0.34,
              groupBounds.maxX >= 0.82,
              groupBounds.width >= 0.30,
              groupBounds.width <= 0.78,
              groupBounds.height >= 0.34,
              groupBounds.height <= 0.90,
              verticalStrokeCount >= 2,
              lowerStrokeCount >= 2,
              absoluteLowerCoverage >= 0.24,
              lowerCoverage >= 0.24,
              rightEdgeCoverage >= 0.10,
              !sharpLikeCluster,
              confidence >= 0.58 else {
            return nil
        }

        return MinorSuffixDetection(
            strokeIndices: Set(rightSideStrokes.map(\.index)),
            bounds: groupBounds,
            confidence: min(0.92, max(0.74, confidence)),
            debugSummary: "minor min-word suffix strokes=\(rightSideStrokes.count) bounds=\(debugBounds(groupBounds))",
            prefersLeftRegionRoot: true
        )
    }

    private static func compactLetterSuffixDetection(in observations: [QualityStrokeObservation]) -> MinorSuffixDetection? {
        let rightSideStrokes = observations.filter { observation in
            observation.bounds.minX >= 0.40
                && observation.bounds.maxX >= 0.52
                && observation.bounds.height >= 0.12
                && observation.bounds.height <= 0.72
                && observation.bounds.width <= 0.62
        }
        guard !rightSideStrokes.isEmpty,
              rightSideStrokes.count <= 5 else {
            return nil
        }

        let groupBounds = unionBounds(for: rightSideStrokes)
        let suffixPoints = rightSideStrokes.flatMap(\.points)
        let verticalStrokeCount = rightSideStrokes.filter { observation in
            observation.bounds.height >= 0.18
                && observation.bounds.width <= 0.40
        }.count
        let lowerCoverage = fraction(of: suffixPoints) { $0.y >= groupBounds.minY + groupBounds.height * 0.45 }
        let upperCoverage = fraction(of: suffixPoints) { $0.y <= groupBounds.minY + groupBounds.height * 0.42 }
        let middleValleyCoverage = fraction(of: suffixPoints) { point in
            (groupBounds.minX + groupBounds.width * 0.24...groupBounds.minX + groupBounds.width * 0.78).contains(point.x)
                && point.y <= groupBounds.minY + groupBounds.height * 0.52
        }
        let aspectRatio = Double(groupBounds.width / max(0.0001, groupBounds.height))
        let flatLikeAccidental = groupBounds.height >= 0.42
            && aspectRatio <= 0.70
            && verticalStrokeCount >= 1
            && rightSideStrokes.count <= 3
        let nearbyTallAccidentalStem = observations.contains { observation in
            !rightSideStrokes.contains(observation)
                && observation.bounds.height >= 0.52
                && observation.bounds.width <= 0.18
                && observation.bounds.maxX >= groupBounds.minX - 0.06
                && observation.bounds.minX <= groupBounds.minX + 0.12
        }

        var confidence = 0.0
        confidence += min(1, Double(verticalStrokeCount) / 2) * 0.24
        confidence += min(1, lowerCoverage / 0.35) * 0.18
        confidence += min(1, upperCoverage / 0.22) * 0.18
        confidence += min(1, middleValleyCoverage / 0.12) * 0.14
        confidence += score(aspectRatio, target: 0.95, tolerance: 0.80) * 0.16
        confidence += score(Double(groupBounds.midX), target: 0.78, tolerance: 0.30) * 0.10

        guard groupBounds.minX >= 0.42,
              groupBounds.width >= 0.12,
              groupBounds.height >= 0.18,
              groupBounds.height <= 0.68,
              verticalStrokeCount >= 1,
              lowerCoverage >= 0.22,
              upperCoverage >= 0.12,
              !flatLikeAccidental,
              !nearbyTallAccidentalStem,
              confidence >= 0.58 else {
            return nil
        }

        return MinorSuffixDetection(
            strokeIndices: Set(rightSideStrokes.map(\.index)),
            bounds: groupBounds,
            confidence: min(0.90, max(0.70, confidence)),
            debugSummary: "minor letter suffix strokes=\(rightSideStrokes.count) bounds=\(debugBounds(groupBounds))",
            prefersLeftRegionRoot: true
        )
    }

    private static func unionBounds(for observations: [QualityStrokeObservation]) -> CGRect {
        observations
            .map(\.bounds)
            .dropFirst()
            .reduce(observations.first?.bounds ?? .null) { $0.union($1) }
    }

    private static func fraction(
        of points: [CGPoint],
        matching predicate: (CGPoint) -> Bool
    ) -> Double {
        guard !points.isEmpty else {
            return 0
        }

        return Double(points.filter(predicate).count) / Double(points.count)
    }

    private static func methodSupportBoost(for method: ChordRecognitionMethod) -> Double {
        switch method {
        case .strokeRootShape:
            return 0.05
        case .rasterTemplate:
            return 0.03
        case .confirmedExample:
            return 0.07
        case .confirmedBoundary:
            return 0.05
        case .textOCRExact:
            return 0.02
        }
    }

    private static func rootConfidenceWeight(for method: ChordRecognitionMethod) -> Double {
        switch method {
        case .confirmedExample:
            return 0.80
        case .confirmedBoundary:
            return 0.77
        case .strokeRootShape:
            return 0.70
        case .rasterTemplate:
            return 0.68
        case .textOCRExact:
            return 0.68
        }
    }

    private static func score(_ value: Double, target: Double, tolerance: Double) -> Double {
        max(0, 1 - abs(value - target) / max(0.0001, tolerance))
    }

    private static func debugBounds(_ bounds: CGRect) -> String {
        "(\(String(format: "%.2f", bounds.minX)),\(String(format: "%.2f", bounds.minY)),\(String(format: "%.2f", bounds.width)),\(String(format: "%.2f", bounds.height)))"
    }

    private static func boundsAreVerticallyRelated(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let verticalOverlap = max(0, min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY))
        let smallerHeight = max(0.0001, min(lhs.height, rhs.height))
        let midYDistance = abs(lhs.midY - rhs.midY)
        return verticalOverlap / smallerHeight >= 0.20 || midYDistance <= 0.16
    }

    private static func absoluteBounds(for stroke: [CGPoint]) -> CGRect? {
        guard let firstPoint = stroke.first else {
            return nil
        }

        return stroke.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialResult, point in
            partialResult.union(CGRect(origin: point, size: .zero))
        }
    }

    private struct MinorSuffixDetection {
        var strokeIndices: Set<Int>
        var bounds: CGRect
        var confidence: Double
        var debugSummary: String
        var prefersLeftRegionRoot: Bool
    }

    private struct QualityStrokeObservation: Hashable {
        var index: Int
        var points: [CGPoint]
        var bounds: CGRect

        init?(index: Int, stroke: [CGPoint], sampleBounds: CGRect) {
            guard !stroke.isEmpty,
                  sampleBounds.width > 0.5,
                  sampleBounds.height > 0.5 else {
                return nil
            }

            self.index = index
            points = stroke.map { point in
                CGPoint(
                    x: (point.x - sampleBounds.minX) / sampleBounds.width,
                    y: (point.y - sampleBounds.minY) / sampleBounds.height
                )
            }

            guard let firstPoint = points.first else {
                return nil
            }

            bounds = points.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialResult, point in
                partialResult.union(CGRect(origin: point, size: .zero))
            }
        }

        var isMostlyHorizontal: Bool {
            bounds.width >= 0.10
                && bounds.height <= 0.18
                && bounds.width >= bounds.height * 1.7
        }

        var isMinorDashLike: Bool {
            bounds.width >= 0.06
                && bounds.height <= 0.22
                && bounds.width >= bounds.height * 0.85
        }
    }
}

private enum RootAccidentalShapeChordClassifier {
    static func candidates(
        from sample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample],
        maximumRootCandidates: Int = 3,
        allowsFlatSecondaryBRoot: Bool = false
    ) -> [ChordRecognitionCandidate] {
        accidentalDetections(in: sample).flatMap { detection -> [ChordRecognitionCandidate] in
            guard let rootSample = sample.excludingStrokeIndices(detection.strokeIndices) else {
                return []
            }

            let rootCandidates = naturalRootCandidates(
                from: rootSample,
                confirmedExamples: confirmedExamples
            )
            let contextAdjustedRootCandidates = accidentalContextAdjustedRootCandidates(
                rootCandidates,
                rootSample: rootSample
            )
            let strongestRootCandidates = strongestNaturalRootCandidates(
                from: contextAdjustedRootCandidates,
                maximumCount: maximumRootCandidates
            )
            let resolvedRootCandidates = flatSecondaryRootResolvedCandidates(
                from: contextAdjustedRootCandidates,
                selectedCandidates: strongestRootCandidates,
                detection: detection,
                allowsFlatSecondaryBRoot: allowsFlatSecondaryBRoot
            )

            return resolvedRootCandidates.compactMap { rootCandidate in
                let displayText = "\(rootCandidate.match.symbol.root.rawValue)\(detection.accidental.rawValue)"
                guard let match = ChordRecognitionCompendium.match(displayText) else {
                    return nil
                }

                let confidence = min(
                    0.985,
                    max(
                        0.70,
                        rootCandidate.confidence * rootConfidenceWeight(for: rootCandidate.method)
                            + detection.confidence * 0.20
                            + methodSupportBoost(for: rootCandidate.method)
                    )
                )

                return ChordRecognitionCandidate(
                    method: rootCandidate.method,
                    match: match,
                    confidence: confidence,
                    debugSummary: "\(rootCandidate.match.displayText)+\(detection.accidental.rawValue) rootAccidentalShape rootMethod=\(rootCandidate.method.rawValue) root=\(String(format: "%.2f", rootCandidate.confidence)) accidental=\(String(format: "%.2f", detection.confidence)) rootStrokes=\(rootSample.strokes.count) rootSummary={\(rootCandidate.debugSummary)} \(detection.debugSummary)"
                )
            }
        }
    }

    private static func naturalRootCandidates(
        from rootSample: ChordRecognitionInkSample,
        confirmedExamples: [ChordRecognitionLearningExample]
    ) -> [ChordRecognitionCandidate] {
        var candidates = ConfirmedChordExampleClassifier.candidates(
            from: rootSample,
            confirmedExamples: confirmedExamples
        )
        candidates.append(contentsOf: StrokeRootShapeChordClassifier.candidates(from: rootSample))
        candidates.append(contentsOf: RasterTemplateChordClassifier.candidates(from: rootSample))

        return ConfirmedChordCorrectionPenalty.adjustedCandidates(
            candidates,
            from: rootSample,
            confirmedExamples: confirmedExamples
        )
    }

    private static func accidentalContextAdjustedRootCandidates(
        _ candidates: [ChordRecognitionCandidate],
        rootSample: ChordRecognitionInkSample
    ) -> [ChordRecognitionCandidate] {
        var adjustedCandidates = candidates

        if let dContextCandidate = dSingleStemBowlCandidate(from: rootSample) {
            adjustedCandidates = adjustedCandidates.map { candidate in
                guard candidate.match.displayText == "B" else {
                    return candidate
                }

                var adjustedCandidate = candidate
                adjustedCandidate.confidence = max(0.50, adjustedCandidate.confidence - 0.10)
                adjustedCandidate.debugSummary += " accidentalDContextPenalty=0.10"
                return adjustedCandidate
            }
            upsert(dContextCandidate, into: &adjustedCandidates)
        }

        if let gContextCandidate = gOpenLoopSpurCandidate(from: rootSample) {
            adjustedCandidates = adjustedCandidates.map { candidate in
                guard candidate.match.displayText == "B" || candidate.match.displayText == "E" else {
                    return candidate
                }

                var adjustedCandidate = candidate
                adjustedCandidate.confidence = max(0.50, adjustedCandidate.confidence - 0.08)
                adjustedCandidate.debugSummary += " accidentalGContextPenalty=0.08"
                return adjustedCandidate
            }
            upsert(gContextCandidate, into: &adjustedCandidates)
        }

        if let fContextCandidate = fStemTwoBarCandidate(from: rootSample) {
            adjustedCandidates = adjustedCandidates.map { candidate in
                guard candidate.match.displayText == "D" || candidate.match.displayText == "B" else {
                    return candidate
                }

                var adjustedCandidate = candidate
                adjustedCandidate.confidence = max(0.50, adjustedCandidate.confidence - 0.12)
                adjustedCandidate.debugSummary += " accidentalFContextPenalty=0.12"
                return adjustedCandidate
            }
            upsert(fContextCandidate, into: &adjustedCandidates)
        }

        return adjustedCandidates
    }

    private static func flatSecondaryRootResolvedCandidates(
        from candidates: [ChordRecognitionCandidate],
        selectedCandidates: [ChordRecognitionCandidate],
        detection: AccidentalDetection,
        allowsFlatSecondaryBRoot: Bool
    ) -> [ChordRecognitionCandidate] {
        guard allowsFlatSecondaryBRoot,
              detection.accidental == .flat else {
            return selectedCandidates
        }

        var resolvedCandidates = selectedCandidates
        appendSecondaryFlatRootCandidate(
            root: "B",
            candidates: candidates,
            selectedCandidates: selectedCandidates,
            allowedLeadingRoots: ["A", "D", "E", "F", "G"],
            floorOffset: 0,
            into: &resolvedCandidates
        )
        appendSecondaryFlatRootCandidate(
            root: "A",
            candidates: candidates,
            selectedCandidates: selectedCandidates,
            allowedLeadingRoots: ["B", "C", "E", "F", "G"],
            floorOffset: -0.02,
            into: &resolvedCandidates
        )

        return resolvedCandidates
    }

    private static func appendSecondaryFlatRootCandidate(
        root: String,
        candidates: [ChordRecognitionCandidate],
        selectedCandidates: [ChordRecognitionCandidate],
        allowedLeadingRoots: Set<String>,
        floorOffset: Double,
        into resolvedCandidates: inout [ChordRecognitionCandidate]
    ) {
        guard let leadingCandidate = selectedCandidates.first,
              allowedLeadingRoots.contains(leadingCandidate.match.displayText),
              !resolvedCandidates.contains(where: { $0.match.displayText == root }) else {
            return
        }

        guard var rescuedCandidate = candidates
            .filter({
                $0.match.displayText == root
                    && $0.match.symbol.accidental == .natural
                    && $0.match.symbol.quality.isEmpty
            })
            .max(by: { $0.confidence < $1.confidence }) else {
            return
        }

        let isLearnedCandidate = rescuedCandidate.method == .confirmedExample || rescuedCandidate.method == .confirmedBoundary
        if root == "A" {
            guard isLearnedCandidate,
                  confirmedSupport(in: rescuedCandidate.debugSummary) >= 4.0 else {
                return
            }
        }

        let confidenceFloor: Double = (isLearnedCandidate ? 0.56 : 0.64) + floorOffset
        let maximumGap: Double = isLearnedCandidate ? 0.42 : 0.30
        let rootGap = leadingCandidate.confidence - rescuedCandidate.confidence
        guard rescuedCandidate.confidence >= confidenceFloor,
              rootGap >= 0,
              rootGap <= maximumGap else {
            return
        }

        let rescuedConfidence = max(
            rescuedCandidate.confidence,
            leadingCandidate.confidence - (isLearnedCandidate ? 0.020 : 0.050)
        )
        rescuedCandidate.confidence = min(0.97, rescuedConfidence)
        rescuedCandidate.debugSummary += " flatMinorSecondary\(root)RootRescueAgainst=\(leadingCandidate.match.displayText) gap=\(String(format: "%.3f", rootGap))"

        resolvedCandidates.append(rescuedCandidate)
    }

    private static func confirmedSupport(in debugSummary: String) -> Double {
        guard let range = debugSummary.range(of: "support=") else {
            return 0
        }

        let suffix = debugSummary[range.upperBound...]
        let number = suffix.prefix { character in
            character.isNumber || character == "."
        }
        return Double(number) ?? 0
    }

    private static func upsert(
        _ candidate: ChordRecognitionCandidate,
        into candidates: inout [ChordRecognitionCandidate]
    ) {
        if let existingIndex = candidates.firstIndex(where: { $0.match.displayText == candidate.match.displayText }) {
            if candidates[existingIndex].confidence < candidate.confidence {
                candidates[existingIndex] = candidate
            }
        } else {
            candidates.append(candidate)
        }
    }

    private static func dSingleStemBowlCandidate(from rootSample: ChordRecognitionInkSample) -> ChordRecognitionCandidate? {
        let strokes = rootSample.normalizedStrokes
        let points = rootSample.normalizedPoints
        guard points.count >= 10,
              !strokes.isEmpty,
              let match = ChordRecognitionCompendium.match("D") else {
            return nil
        }

        let strokeBounds = strokes.compactMap(normalizedBounds)
        let stemSpan = strokeBounds
            .filter { bounds in
                (0.12...0.42).contains(bounds.midX)
                    && bounds.width <= 0.18
                    && bounds.height >= 0.56
            }
            .map { Double($0.height) }
            .max() ?? 0
        let bowlSpan = strokeBounds
            .filter { bounds in
                bounds.width >= 0.48
                    && bounds.height >= 0.45
                    && bounds.maxX >= 0.55
                    && bounds.maxY >= 0.72
            }
            .map { bounds in Double(bounds.width + bounds.height) / 2 }
            .max() ?? 0
        let rightArcCoverage = fraction(of: points) { $0.x >= 0.58 && (0.20...0.88).contains($0.y) }
        let topCoverage = fraction(of: points) { $0.y <= 0.30 }
        let bottomCoverage = fraction(of: points) { $0.y >= 0.72 }
        let waistBridgeCoverage = fraction(of: points) { (0.22...0.62).contains($0.x) && (0.34...0.66).contains($0.y) }

        var confidence = 0.0
        confidence += min(1, stemSpan / 0.72) * 0.32
        confidence += min(1, bowlSpan / 0.62) * 0.24
        confidence += min(1, rightArcCoverage / 0.14) * 0.18
        confidence += min(1, topCoverage / 0.16) * 0.10
        confidence += min(1, bottomCoverage / 0.14) * 0.10
        confidence += (1 - min(1, waistBridgeCoverage / 0.18)) * 0.06

        guard stemSpan >= 0.58,
              bowlSpan >= 0.54,
              rightArcCoverage >= 0.10,
              topCoverage >= 0.10,
              bottomCoverage >= 0.08,
              confidence >= 0.70 else {
            return nil
        }

        return ChordRecognitionCandidate(
            method: .strokeRootShape,
            match: match,
            confidence: min(0.94, max(0.78, confidence)),
            debugSummary: "D accidental-context single-stem/bowl root geometry stem=\(String(format: "%.2f", stemSpan)) bowl=\(String(format: "%.2f", bowlSpan))"
        )
    }

    private static func gOpenLoopSpurCandidate(from rootSample: ChordRecognitionInkSample) -> ChordRecognitionCandidate? {
        let points = rootSample.normalizedPoints
        guard rootSample.strokes.count == 1,
              points.count >= 12,
              !hasContextStraightStem(in: rootSample),
              let match = ChordRecognitionCompendium.match("G") else {
            return nil
        }

        let leftCoverage = fraction(of: points) { $0.x <= 0.34 }
        let topCoverage = fraction(of: points) { $0.y <= 0.32 }
        let bottomCoverage = fraction(of: points) { $0.y >= 0.72 }
        let rightMiddleCoverage = fraction(of: points) { $0.x >= 0.58 && (0.38...0.72).contains($0.y) }
        let spurSpan = horizontalSpan(of: points.filter { (0.44...0.72).contains($0.y) && $0.x >= 0.42 })
        let innerReturnCoverage = fraction(of: points) { (0.28...0.58).contains($0.x) && (0.58...0.86).contains($0.y) }

        var confidence = 0.0
        confidence += min(1, leftCoverage / 0.18) * 0.18
        confidence += min(1, topCoverage / 0.12) * 0.14
        confidence += min(1, bottomCoverage / 0.12) * 0.14
        confidence += min(1, rightMiddleCoverage / 0.05) * 0.24
        confidence += min(1, spurSpan / 0.16) * 0.20
        confidence += min(1, innerReturnCoverage / 0.08) * 0.10

        guard leftCoverage >= 0.12,
              topCoverage >= 0.08,
              bottomCoverage >= 0.08,
              rightMiddleCoverage >= 0.04,
              spurSpan >= 0.12,
              confidence >= 0.70 else {
            return nil
        }

        return ChordRecognitionCandidate(
            method: .strokeRootShape,
            match: match,
            confidence: min(0.91, max(0.80, confidence)),
            debugSummary: "G accidental-context open-loop/spur root geometry spur=\(String(format: "%.2f", spurSpan))"
        )
    }

    private static func fStemTwoBarCandidate(from rootSample: ChordRecognitionInkSample) -> ChordRecognitionCandidate? {
        let points = rootSample.normalizedPoints
        let strokes = rootSample.normalizedStrokes
        guard points.count >= 8,
              !strokes.isEmpty,
              let match = ChordRecognitionCompendium.match("F") else {
            return nil
        }

        let strokeBounds = strokes.compactMap(normalizedBounds)
        let leftStemSpan = strokeBounds
            .filter { bounds in
                bounds.midX <= 0.26
                    && bounds.width <= 0.20
                    && bounds.height >= 0.48
            }
            .map { Double($0.height) }
            .max() ?? 0
        let topSpan = horizontalSpan(of: points.filter { $0.y <= 0.28 })
        let middleSpan = horizontalSpan(of: points.filter { (0.36...0.76).contains($0.y) })
        let bottomSpan = horizontalSpan(of: points.filter { $0.y >= 0.82 })
        let lowerRightCoverage = fraction(of: points) { $0.x >= 0.52 && $0.y >= 0.70 }
        let rightBowlCoverage = fraction(of: points) { $0.x >= 0.58 && (0.22...0.82).contains($0.y) }

        var confidence = 0.0
        confidence += min(1, leftStemSpan / 0.66) * 0.30
        confidence += min(1, topSpan / 0.48) * 0.25
        confidence += min(1, middleSpan / 0.36) * 0.25
        confidence += (1 - min(1, bottomSpan / 0.28)) * 0.08
        confidence += (1 - min(1, lowerRightCoverage / 0.14)) * 0.06
        confidence += (1 - min(1, rightBowlCoverage / 0.22)) * 0.06

        guard leftStemSpan >= 0.56,
              topSpan >= 0.36,
              middleSpan >= 0.30,
              bottomSpan <= 0.34,
              lowerRightCoverage <= 0.16,
              confidence >= 0.72 else {
            return nil
        }

        return ChordRecognitionCandidate(
            method: .strokeRootShape,
            match: match,
            confidence: min(0.96, max(0.84, confidence)),
            debugSummary: "F accidental-context stem/two-bar root geometry stem=\(String(format: "%.2f", leftStemSpan)) middle=\(String(format: "%.2f", middleSpan))"
        )
    }

    private static func strongestNaturalRootCandidates(
        from candidates: [ChordRecognitionCandidate],
        maximumCount: Int
    ) -> [ChordRecognitionCandidate] {
        let naturalCandidates = candidates.filter {
            $0.match.symbol.accidental == .natural
                && $0.match.symbol.quality.isEmpty
        }
        let report = ChordRecognitionReport(candidates: naturalCandidates)
        return Array(report.strongestCandidatesBySymbol.prefix(max(1, maximumCount)))
    }

    private static func methodSupportBoost(for method: ChordRecognitionMethod) -> Double {
        switch method {
        case .strokeRootShape:
            return 0.06
        case .rasterTemplate:
            return 0.04
        case .confirmedExample, .confirmedBoundary, .textOCRExact:
            return 0.02
        }
    }

    private static func rootConfidenceWeight(for method: ChordRecognitionMethod) -> Double {
        switch method {
        case .confirmedExample:
            return 0.78
        case .confirmedBoundary:
            return 0.76
        case .strokeRootShape:
            return 0.74
        case .rasterTemplate:
            return 0.72
        case .textOCRExact:
            return 0.70
        }
    }

    private static func accidentalDetections(in sample: ChordRecognitionInkSample) -> [AccidentalDetection] {
        guard let sampleBounds = sample.bounds,
              sample.strokes.count >= 2,
              sampleBounds.width > 12,
              sampleBounds.height > 8 else {
            return []
        }

        let observations = sample.strokes.enumerated().compactMap { index, stroke in
            StrokeObservation(index: index, stroke: stroke, sampleBounds: sampleBounds)
        }
        let rightSideObservations = observations.filter { observation in
            observation.isRightSideAccidentalCandidate
                || observation.isLeftStartingSharpCrossbarCandidate
        }

        guard !rightSideObservations.isEmpty else {
            return []
        }

        let sharp = sharpDetection(in: rightSideObservations)
        let flat = flatDetection(in: rightSideObservations)

        if let sharp,
           let flat,
           sharp.strokeIndices.count >= 4,
           sharp.confidence >= flat.confidence - 0.06 {
            return [sharp]
        }

        return [sharp, flat]
            .compactMap(\.self)
            .sorted { $0.confidence > $1.confidence }
    }

    private static func sharpDetection(in observations: [StrokeObservation]) -> AccidentalDetection? {
        let verticalStrokes = observations.filter(\.isMostlyVertical)
        let horizontalStrokes = observations.filter { $0.isMostlyHorizontal || $0.isSharpCrossbarLike }
        let diagonalStrokes = observations.filter(\.isSharpLikeDiagonal)
        let candidateStrokes = Array(Set(verticalStrokes + horizontalStrokes + diagonalStrokes))
        let candidateIndices = Set(candidateStrokes.map(\.index))

        guard candidateIndices.count >= 3 else {
            return nil
        }

        let groupBounds = unionBounds(for: candidateStrokes)
        let verticalCoverage = verticalStrokes.reduce(0) { $0 + $1.bounds.height }
        let horizontalCoverage = horizontalStrokes.reduce(0) { $0 + $1.bounds.width }
        let lineFamilyCount = min(2, verticalStrokes.count) + min(2, horizontalStrokes.count) + min(1, diagonalStrokes.count)

        var confidence = 0.0
        confidence += min(1, Double(verticalStrokes.count) / 2) * 0.28
        confidence += min(1, Double(horizontalStrokes.count) / 2) * 0.28
        confidence += min(1, verticalCoverage / 0.90) * 0.16
        confidence += min(1, horizontalCoverage / 0.36) * 0.14
        confidence += score(Double(groupBounds.midX), target: 0.78, tolerance: 0.28) * 0.08
        confidence += min(1, Double(lineFamilyCount) / 4) * 0.06

        guard verticalStrokes.count >= 1,
              horizontalStrokes.count >= 1,
              lineFamilyCount >= 3,
              groupBounds.minX >= 0.30,
              groupBounds.width <= 0.70,
              groupBounds.height >= 0.28,
              confidence >= 0.58 else {
            return nil
        }

        return AccidentalDetection(
            accidental: .sharp,
            strokeIndices: candidateIndices,
            confidence: min(0.94, max(0.72, confidence)),
            debugSummary: "sharp strokes=\(candidateIndices.count) bounds=\(debugBounds(groupBounds))"
        )
    }

    private static func flatDetection(in observations: [StrokeObservation]) -> AccidentalDetection? {
        let candidateStrokes = observations.filter { observation in
            observation.bounds.minX >= 0.42
                && observation.bounds.width <= 0.60
                && observation.bounds.height >= 0.12
        }
        guard !candidateStrokes.isEmpty,
              candidateStrokes.count <= 3 else {
            return nil
        }

        let groupBounds = unionBounds(for: candidateStrokes)
        let verticalStrokes = candidateStrokes.filter { observation in
            observation.isMostlyVertical
                || observation.isFlatStemLike
                || (
                    observation.bounds.height >= 0.16
                        && observation.bounds.width <= 0.20
                        && observation.bounds.height >= observation.bounds.width * 1.05
                )
        }
        let curvedStrokeCount = candidateStrokes.filter { observation in
            !observation.isMostlyHorizontal
                && observation.bounds.width >= 0.06
                && observation.bounds.height >= 0.16
                && observation.bounds.width / max(0.0001, observation.bounds.height) >= 0.24
        }.count
        let bowlStrokeCount = candidateStrokes.filter { observation in
            observation.bounds.width >= 0.20
                && observation.bounds.height >= 0.14
                && observation.bounds.minY <= 0.56
                && observation.bounds.maxY >= 0.28
        }.count
        guard !verticalStrokes.isEmpty,
              curvedStrokeCount >= 1 || bowlStrokeCount >= 1 else {
            return nil
        }

        let localPoints = candidateStrokes.flatMap { observation in
            observation.points.map { point in
                CGPoint(
                    x: (point.x - groupBounds.minX) / max(0.0001, groupBounds.width),
                    y: (point.y - groupBounds.minY) / max(0.0001, groupBounds.height)
                )
            }
        }
        let stemSpan = verticalSpan(of: localPoints.filter { $0.x <= 0.42 })
        let upperStemCoverage = fraction(of: localPoints) { $0.x <= 0.46 && $0.y <= 0.36 }
        let lowerRightCoverage = fraction(of: localPoints) { $0.x >= 0.42 && $0.y >= 0.34 }
        let lowerBowlSpan = horizontalSpan(of: localPoints.filter { $0.y >= 0.35 })
        let topRightCoverage = fraction(of: localPoints) { $0.x >= 0.58 && $0.y <= 0.28 }
        let aspectRatio = Double(groupBounds.width / max(0.0001, groupBounds.height))

        var confidence = 0.0
        confidence += min(1, stemSpan / 0.54) * 0.30
        confidence += min(1, upperStemCoverage / 0.15) * 0.16
        confidence += min(1, lowerRightCoverage / 0.16) * 0.22
        confidence += min(1, lowerBowlSpan / 0.30) * 0.16
        confidence += (1 - min(1, topRightCoverage / 0.20)) * 0.08
        confidence += score(aspectRatio, target: 0.38, tolerance: 0.36) * 0.08

        guard groupBounds.minX >= 0.42,
              groupBounds.width <= 0.60,
              groupBounds.height >= 0.22,
              stemSpan >= 0.34,
              lowerRightCoverage >= 0.06,
              lowerBowlSpan >= 0.14,
              topRightCoverage <= 0.28,
              confidence >= 0.50 else {
            return nil
        }

        return AccidentalDetection(
            accidental: .flat,
            strokeIndices: Set(candidateStrokes.map(\.index)),
            confidence: min(0.92, max(0.70, confidence)),
            debugSummary: "flat strokes=\(candidateStrokes.count) bounds=\(debugBounds(groupBounds))"
        )
    }

    private static func unionBounds(for observations: [StrokeObservation]) -> CGRect {
        observations
            .map(\.bounds)
            .dropFirst()
            .reduce(observations.first?.bounds ?? .null) { $0.union($1) }
    }

    private static func normalizedBounds(for stroke: [CGPoint]) -> CGRect? {
        guard let firstPoint = stroke.first else {
            return nil
        }

        return stroke.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialResult, point in
            partialResult.union(CGRect(origin: point, size: .zero))
        }
    }

    private static func horizontalSpan(of points: [CGPoint]) -> Double {
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max() else {
            return 0
        }

        return Double(maxX - minX)
    }

    private static func verticalSpan(of points: [CGPoint]) -> Double {
        guard let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else {
            return 0
        }

        return Double(maxY - minY)
    }

    private static func hasContextStraightStem(in sample: ChordRecognitionInkSample) -> Bool {
        sample.normalizedStrokes.contains { stroke in
            guard let bounds = normalizedBounds(for: stroke) else {
                return false
            }

            return bounds.midX <= 0.38
                && bounds.width <= 0.18
                && bounds.height >= 0.55
        }
    }

    private static func fraction(
        of points: [CGPoint],
        matching predicate: (CGPoint) -> Bool
    ) -> Double {
        guard !points.isEmpty else {
            return 0
        }

        return Double(points.filter(predicate).count) / Double(points.count)
    }

    private static func score(_ value: Double, target: Double, tolerance: Double) -> Double {
        max(0, 1 - abs(value - target) / max(0.0001, tolerance))
    }

    private static func debugBounds(_ bounds: CGRect) -> String {
        "(\(String(format: "%.2f", bounds.minX)),\(String(format: "%.2f", bounds.minY)),\(String(format: "%.2f", bounds.width)),\(String(format: "%.2f", bounds.height)))"
    }

    private struct AccidentalDetection {
        var accidental: Accidental
        var strokeIndices: Set<Int>
        var confidence: Double
        var debugSummary: String
    }

    private struct StrokeObservation: Hashable {
        var index: Int
        var points: [CGPoint]
        var bounds: CGRect

        init?(index: Int, stroke: [CGPoint], sampleBounds: CGRect) {
            guard !stroke.isEmpty,
                  sampleBounds.width > 0.5,
                  sampleBounds.height > 0.5 else {
                return nil
            }

            self.index = index
            self.points = stroke.map { point in
                CGPoint(
                    x: (point.x - sampleBounds.minX) / sampleBounds.width,
                    y: (point.y - sampleBounds.minY) / sampleBounds.height
                )
            }

            guard let firstPoint = points.first else {
                return nil
            }

            self.bounds = points.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialResult, point in
                partialResult.union(CGRect(origin: point, size: .zero))
            }
        }

        var isMostlyVertical: Bool {
            bounds.height >= 0.22 && bounds.width <= 0.24 && bounds.height >= bounds.width * 1.55
        }

        var isFlatStemLike: Bool {
            bounds.height >= 0.16 && bounds.width <= 0.24 && bounds.height >= bounds.width * 1.12
        }

        var isMostlyHorizontal: Bool {
            bounds.width >= 0.14 && bounds.height <= 0.18 && bounds.width >= bounds.height * 1.7
        }

        var isSharpLikeDiagonal: Bool {
            guard bounds.height >= 0.18,
                  bounds.width >= 0.08,
                  bounds.width <= 0.32,
                  let first = points.first,
                  let last = points.last else {
                return false
            }

            let angle = abs(atan2(last.y - first.y, last.x - first.x))
            return (0.60...1.35).contains(Double(angle))
                || (1.80...2.55).contains(Double(angle))
        }

        var isSharpCrossbarLike: Bool {
            bounds.width >= 0.20
                && bounds.width <= 0.58
                && bounds.height <= 0.42
                && bounds.width >= bounds.height * 1.05
        }

        var isRightSideAccidentalCandidate: Bool {
            bounds.midX >= 0.46
                && bounds.minX >= 0.40
                && bounds.maxX >= 0.52
                && bounds.width <= 0.62
        }

        var isLeftStartingSharpCrossbarCandidate: Bool {
            isSharpCrossbarLike
                && bounds.minX >= 0.30
                && bounds.maxX >= 0.66
                && bounds.midX >= 0.50
                && bounds.maxY <= 0.56
        }
    }
}

private enum StrokeRootShapeChordClassifier {
    static func candidates(from sample: ChordRecognitionInkSample) -> [ChordRecognitionCandidate] {
        var candidates: [ChordRecognitionCandidate] = []

        if let cConfidence = cShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("C") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: cConfidence,
                    debugSummary: "C arc/open-right stroke geometry"
                )
            )
        }

        if let aConfidence = aShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("A") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: aConfidence,
                    debugSummary: "A apex/crossbar stroke geometry"
                )
            )
        }

        let bConfidence = bShapeConfidence(sample)
        if let bConfidence,
           let match = ChordRecognitionCompendium.match("B") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: bConfidence,
                    debugSummary: "B stem/waist/two-bowl stroke geometry"
                )
            )
        }

        if bConfidence == nil,
           let dConfidence = dShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("D") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: dConfidence,
                    debugSummary: "D stem-and-bowl stroke geometry"
                )
            )
        }

        if let eConfidence = eShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("E") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: eConfidence,
                    debugSummary: "E stem/three-bar stroke geometry"
                )
            )
        }

        if let fConfidence = fShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("F") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: fConfidence,
                    debugSummary: "F stem/two-bar stroke geometry"
                )
            )
        }

        if let gConfidence = gShapeConfidence(sample),
           let match = ChordRecognitionCompendium.match("G") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: match,
                    confidence: gConfidence,
                    debugSummary: "G open curve/spur stroke geometry"
                )
            )
        }

        return candidates
    }

    private static func aShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 8,
              let bounds = sample.bounds,
              bounds.width >= 6,
              bounds.height >= 8 else {
            return nil
        }

        let apexCoverage = fraction(of: points) { (0.32...0.68).contains($0.x) && $0.y < 0.24 }
        let leftBaseCoverage = fraction(of: points) { $0.x < 0.38 && $0.y > 0.58 }
        let rightBaseCoverage = fraction(of: points) { $0.x > 0.62 && $0.y > 0.58 }
        let crossbarSpan = horizontalSpan(in: sample, yRange: 0.40...0.64, xRange: 0.20...0.82)
        let lowerOpenCoverage = fraction(of: points) { (0.34...0.66).contains($0.x) && $0.y > 0.70 }
        let leftStemSpan = leftStemVerticalSpan(in: sample)
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += min(1, apexCoverage / 0.08) * 0.22
        confidence += min(1, leftBaseCoverage / 0.14) * 0.18
        confidence += min(1, rightBaseCoverage / 0.14) * 0.18
        confidence += min(1, crossbarSpan / 0.30) * 0.26
        confidence += (1 - min(1, lowerOpenCoverage / 0.18)) * 0.08
        confidence += score(aspectRatio, target: 0.75, tolerance: 0.60) * 0.08

        guard apexCoverage >= 0.04,
              leftBaseCoverage >= 0.08,
              rightBaseCoverage >= 0.08,
              crossbarSpan >= 0.24,
              leftStemSpan <= 0.52,
              confidence >= 0.62 else {
            return nil
        }

        return min(0.90, max(0.68, confidence))
    }

    private static func bShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 10,
              let bounds = sample.bounds,
              bounds.width >= 7,
              bounds.height >= 8 else {
            return nil
        }

        let leftStemSpan = leftStemVerticalSpan(in: sample)
        let leftCoverage = fraction(of: points) { $0.x < 0.24 }
        let rightCoverage = fraction(of: points) { $0.x > 0.58 }
        let upperRightCoverage = fraction(of: points) { $0.x > 0.55 && (0.04...0.46).contains($0.y) }
        let lowerRightCoverage = fraction(of: points) { $0.x > 0.55 && (0.46...0.96).contains($0.y) }
        let waistBridgeCoverage = fraction(of: points) { (0.18...0.62).contains($0.x) && (0.34...0.66).contains($0.y) }
        let middleSpan = horizontalSpan(in: sample, yRange: 0.36...0.62, xRange: 0.12...0.95)
        let eLikeMiddleSpan = horizontalSpan(in: sample, yRange: 0.28...0.62, xRange: 0.12...1.00)
        let eLikeRightBowlCoverage = fraction(of: points) { $0.x > 0.58 && (0.22...0.78).contains($0.y) }
        let leftBackbone = leftBackboneMetrics(in: sample)
        let aspectRatio = bounds.width / max(1, bounds.height)

        if max(leftStemSpan, leftBackbone.verticalSpan) >= 0.58,
           leftBackbone.horizontalDrift <= 0.34,
           horizontalSpan(in: sample, yRange: 0.00...0.24) >= 0.34,
           eLikeMiddleSpan >= 0.28,
           horizontalSpan(in: sample, yRange: 0.78...1.00) >= 0.34,
           eLikeRightBowlCoverage <= 0.22 {
            return nil
        }

        var confidence = 0.0
        confidence += min(1, leftStemSpan / 0.64) * 0.22
        confidence += min(1, waistBridgeCoverage / 0.11) * 0.24
        confidence += min(1, upperRightCoverage / 0.09) * 0.16
        confidence += min(1, lowerRightCoverage / 0.09) * 0.16
        confidence += min(1, rightCoverage / 0.18) * 0.10
        confidence += min(1, middleSpan / 0.46) * 0.08
        confidence += score(aspectRatio, target: 0.70, tolerance: 0.62) * 0.04

        guard leftCoverage >= 0.16,
              leftStemSpan >= 0.52,
              waistBridgeCoverage >= 0.07,
              upperRightCoverage >= 0.05,
              lowerRightCoverage >= 0.05,
              rightCoverage >= 0.14,
              middleSpan >= 0.36,
              confidence >= 0.66 else {
            return nil
        }

        return min(0.95, max(0.76, confidence))
    }

    private static func cShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 6,
              let bounds = sample.bounds,
              bounds.width >= 6,
              bounds.height >= 8 else {
            return nil
        }

        let leftCoverage = fraction(of: points) { $0.x < 0.36 }
        let topCoverage = fraction(of: points) { $0.y < 0.30 }
        let bottomCoverage = fraction(of: points) { $0.y > 0.70 }
        let rightMiddleCoverage = fraction(of: points) { $0.x > 0.62 && (0.32...0.68).contains($0.y) }
        let rightTopCoverage = fraction(of: points) { $0.x > 0.50 && $0.y < 0.38 }
        let rightBottomCoverage = fraction(of: points) { $0.x > 0.50 && $0.y > 0.62 }
        let middleCoverage = fraction(of: points) { (0.28...0.72).contains($0.y) }
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += score(leftCoverage, target: 0.36, tolerance: 0.24) * 0.24
        confidence += score(topCoverage, target: 0.28, tolerance: 0.22) * 0.15
        confidence += score(bottomCoverage, target: 0.28, tolerance: 0.22) * 0.15
        confidence += (1 - min(1, rightMiddleCoverage / 0.14)) * 0.26
        confidence += min(1, rightTopCoverage / 0.08) * 0.08
        confidence += min(1, rightBottomCoverage / 0.08) * 0.08
        confidence += score(aspectRatio, target: 0.78, tolerance: 0.55) * 0.04

        guard leftCoverage >= 0.20,
              topCoverage >= 0.12,
              bottomCoverage >= 0.12,
              middleCoverage >= 0.18,
              rightMiddleCoverage <= 0.18,
              rightTopCoverage >= 0.03,
              rightBottomCoverage >= 0.03,
              confidence >= 0.58 else {
            return nil
        }

        return min(0.93, max(0.66, confidence))
    }

    private static func dShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 10,
              let bounds = sample.bounds,
              bounds.width >= 7,
              bounds.height >= 8 else {
            return nil
        }

        let leftCoverage = fraction(of: points) { $0.x < 0.22 }
        let topCoverage = fraction(of: points) { $0.y < 0.28 }
        let bottomCoverage = fraction(of: points) { $0.y > 0.72 }
        let rightCoverage = fraction(of: points) { $0.x > 0.62 }
        let rightMiddleCoverage = fraction(of: points) { $0.x > 0.62 && (0.24...0.76).contains($0.y) }
        let rightTopCoverage = fraction(of: points) { $0.x > 0.55 && $0.y < 0.34 }
        let rightBottomCoverage = fraction(of: points) { $0.x > 0.55 && $0.y > 0.62 }
        let leftStemSpan = leftStemVerticalSpan(in: sample)
        let waistBridgeCoverage = fraction(of: points) { (0.20...0.60).contains($0.x) && (0.34...0.66).contains($0.y) }
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += min(1, leftStemSpan / 0.72) * 0.26
        confidence += min(1, rightMiddleCoverage / 0.16) * 0.20
        confidence += min(1, rightTopCoverage / 0.12) * 0.16
        confidence += min(1, rightCoverage / 0.22) * 0.12
        confidence += min(1, topCoverage / 0.20) * 0.10
        confidence += min(1, bottomCoverage / 0.18) * 0.10
        confidence += score(aspectRatio, target: 0.76, tolerance: 0.58) * 0.06

        guard leftCoverage >= 0.18,
              hasStraightLeftStem(in: sample),
              leftStemSpan >= 0.62,
              rightCoverage >= 0.14,
              rightMiddleCoverage >= 0.10,
              rightTopCoverage >= 0.09,
              topCoverage >= 0.12,
              bottomCoverage >= 0.10,
              rightBottomCoverage >= 0.02,
              waistBridgeCoverage <= 0.09,
              confidence >= 0.68 else {
            return nil
        }

        return min(0.91, max(0.72, confidence))
    }

    private static func eShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 8,
              let bounds = sample.bounds,
              bounds.width >= 6,
              bounds.height >= 8 else {
            return nil
        }

        let leftStemSpan = leftStemVerticalSpan(in: sample)
        let topSpan = horizontalSpan(in: sample, yRange: 0.00...0.24)
        let middleSpan = horizontalSpan(in: sample, yRange: 0.28...0.62)
        let bottomSpan = horizontalSpan(in: sample, yRange: 0.78...1.00)
        let rightBowlCoverage = fraction(of: points) { $0.x > 0.58 && (0.22...0.78).contains($0.y) }
        let leftBackbone = leftBackboneMetrics(in: sample)
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += min(1, max(leftStemSpan, leftBackbone.verticalSpan) / 0.64) * 0.22
        confidence += min(1, topSpan / 0.50) * 0.18
        confidence += min(1, middleSpan / 0.34) * 0.20
        confidence += min(1, bottomSpan / 0.48) * 0.20
        confidence += (1 - min(1, rightBowlCoverage / 0.20)) * 0.12
        confidence += score(aspectRatio, target: 0.66, tolerance: 0.60) * 0.08

        guard max(leftStemSpan, leftBackbone.verticalSpan) >= 0.58,
              leftBackbone.horizontalDrift <= 0.34,
              topSpan >= 0.34,
              middleSpan >= 0.28,
              bottomSpan >= 0.34,
              rightBowlCoverage <= 0.22,
              confidence >= 0.66 else {
            return nil
        }

        return min(0.98, max(0.78, confidence))
    }

    private static func fShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 7,
              let bounds = sample.bounds,
              bounds.width >= 5,
              bounds.height >= 8 else {
            return nil
        }

        let leftStemSpan = leftStemVerticalSpan(in: sample)
        let topSpan = horizontalSpan(in: sample, yRange: 0.00...0.22)
        let middleSpan = horizontalSpan(in: sample, yRange: 0.36...0.62)
        let bottomSpan = horizontalSpan(in: sample, yRange: 0.78...1.00)
        let lowerRightCoverage = fraction(of: points) { $0.x > 0.48 && $0.y > 0.72 }
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += min(1, leftStemSpan / 0.62) * 0.30
        confidence += min(1, topSpan / 0.48) * 0.24
        confidence += min(1, middleSpan / 0.34) * 0.22
        confidence += (1 - min(1, bottomSpan / 0.36)) * 0.12
        confidence += (1 - min(1, lowerRightCoverage / 0.14)) * 0.06
        confidence += score(aspectRatio, target: 0.54, tolerance: 0.56) * 0.06

        guard leftStemSpan >= 0.55,
              topSpan >= 0.36,
              middleSpan >= 0.26,
              bottomSpan <= 0.48,
              lowerRightCoverage <= 0.18,
              confidence >= 0.64 else {
            return nil
        }

        return min(0.87, max(0.68, confidence))
    }

    private static func gShapeConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let points = sample.normalizedPoints
        guard points.count >= 9,
              let bounds = sample.bounds,
              bounds.width >= 6,
              bounds.height >= 8 else {
            return nil
        }

        let leftCoverage = fraction(of: points) { $0.x < 0.34 }
        let topCoverage = fraction(of: points) { $0.y < 0.30 }
        let bottomCoverage = fraction(of: points) { $0.y > 0.70 }
        let rightMiddleCoverage = fraction(of: points) { $0.x > 0.58 && (0.38...0.68).contains($0.y) }
        let spurSpan = horizontalSpan(in: sample, yRange: 0.44...0.68, xRange: 0.42...1.00)
        let rightTopCoverage = fraction(of: points) { $0.x > 0.50 && $0.y < 0.38 }
        let lowerRightCoverage = fraction(of: points) { $0.x > 0.58 && $0.y > 0.58 }
        let aspectRatio = bounds.width / max(1, bounds.height)

        var confidence = 0.0
        confidence += min(1, leftCoverage / 0.26) * 0.18
        confidence += min(1, topCoverage / 0.18) * 0.14
        confidence += min(1, bottomCoverage / 0.16) * 0.14
        confidence += min(1, rightMiddleCoverage / 0.08) * 0.20
        confidence += min(1, spurSpan / 0.24) * 0.18
        confidence += min(1, rightTopCoverage / 0.06) * 0.08
        confidence += min(1, lowerRightCoverage / 0.08) * 0.04
        confidence += score(aspectRatio, target: 0.78, tolerance: 0.58) * 0.04

        guard leftCoverage >= 0.14,
              !hasStraightLeftStem(in: sample),
              topCoverage >= 0.10,
              bottomCoverage >= 0.08,
              rightMiddleCoverage >= 0.04,
              spurSpan >= 0.18,
              confidence >= 0.66 else {
            return nil
        }

        return min(0.89, max(0.70, confidence))
    }

    private static func leftStemVerticalSpan(in sample: ChordRecognitionInkSample) -> Double {
        sample.normalizedStrokes
            .map { stroke in
                let leftSidePoints = stroke.filter { $0.x < 0.20 }
                guard !leftSidePoints.isEmpty else {
                    return 0
                }

                let minY = leftSidePoints.map(\.y).min() ?? 0
                let maxY = leftSidePoints.map(\.y).max() ?? 0
                return Double(maxY - minY)
            }
            .max() ?? 0
    }

    private static func leftBackboneMetrics(in sample: ChordRecognitionInkSample) -> (verticalSpan: Double, horizontalDrift: Double) {
        sample.normalizedStrokes
            .map { stroke in
                let leftSidePoints = stroke.filter { $0.x < 0.34 }
                guard !leftSidePoints.isEmpty else {
                    return (verticalSpan: 0.0, horizontalDrift: Double.greatestFiniteMagnitude)
                }

                let minX = leftSidePoints.map(\.x).min() ?? 0
                let maxX = leftSidePoints.map(\.x).max() ?? 0
                let minY = leftSidePoints.map(\.y).min() ?? 0
                let maxY = leftSidePoints.map(\.y).max() ?? 0
                return (
                    verticalSpan: Double(maxY - minY),
                    horizontalDrift: Double(maxX - minX)
                )
            }
            .max { lhs, rhs in
                if abs(lhs.verticalSpan - rhs.verticalSpan) > 0.0001 {
                    return lhs.verticalSpan < rhs.verticalSpan
                }

                return lhs.horizontalDrift > rhs.horizontalDrift
            }
            ?? (verticalSpan: 0, horizontalDrift: Double.greatestFiniteMagnitude)
    }

    private static func hasStraightLeftStem(in sample: ChordRecognitionInkSample) -> Bool {
        sample.normalizedStrokes.contains { stroke in
            let leftSidePoints = stroke.filter { $0.x < 0.24 }
            guard !leftSidePoints.isEmpty else {
                return false
            }

            let minX = leftSidePoints.map(\.x).min() ?? 0
            let maxX = leftSidePoints.map(\.x).max() ?? 0
            let minY = leftSidePoints.map(\.y).min() ?? 0
            let maxY = leftSidePoints.map(\.y).max() ?? 0
            return Double(maxY - minY) >= 0.62 && Double(maxX - minX) <= 0.16
        }
    }

    private static func horizontalSpan(
        in sample: ChordRecognitionInkSample,
        yRange: ClosedRange<CGFloat>,
        xRange: ClosedRange<CGFloat> = 0...1
    ) -> Double {
        let xs = sample.normalizedPoints
            .filter { yRange.contains($0.y) && xRange.contains($0.x) }
            .map(\.x)
        guard let minX = xs.min(),
              let maxX = xs.max() else {
            return 0
        }

        return Double(maxX - minX)
    }

    private static func fraction(
        of points: [CGPoint],
        matching predicate: (CGPoint) -> Bool
    ) -> Double {
        guard !points.isEmpty else {
            return 0
        }

        return Double(points.filter(predicate).count) / Double(points.count)
    }

    private static func score(_ value: Double, target: Double, tolerance: Double) -> Double {
        max(0, 1 - abs(value - target) / max(0.0001, tolerance))
    }

    private static func score(_ value: CGFloat, target: Double, tolerance: Double) -> Double {
        score(Double(value), target: target, tolerance: tolerance)
    }
}

private enum RasterTemplateChordClassifier {
    private static let gridSize = 9
    private static let cTemplateCells: Set<Int> = [
        index(x: 2, y: 0), index(x: 3, y: 0), index(x: 4, y: 0), index(x: 5, y: 0), index(x: 6, y: 0),
        index(x: 1, y: 1), index(x: 1, y: 2), index(x: 0, y: 3), index(x: 0, y: 4), index(x: 0, y: 5),
        index(x: 1, y: 6), index(x: 1, y: 7),
        index(x: 2, y: 8), index(x: 3, y: 8), index(x: 4, y: 8), index(x: 5, y: 8), index(x: 6, y: 8)
    ]

    static func candidates(from sample: ChordRecognitionInkSample) -> [ChordRecognitionCandidate] {
        var candidates: [ChordRecognitionCandidate] = []

        if let confidence = cTemplateConfidence(sample),
           let match = ChordRecognitionCompendium.match("C") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .rasterTemplate,
                    match: match,
                    confidence: confidence,
                    debugSummary: "C normalized raster template"
                )
            )
        }

        let bTemplateScore = bTemplateConfidence(sample)
        if let confidence = bTemplateScore,
           let match = ChordRecognitionCompendium.match("B") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .rasterTemplate,
                    match: match,
                    confidence: confidence,
                    debugSummary: "B normalized raster template"
                )
            )
        }

        if bTemplateScore == nil,
           let confidence = dTemplateConfidence(sample),
           let match = ChordRecognitionCompendium.match("D") {
            candidates.append(
                ChordRecognitionCandidate(
                    method: .rasterTemplate,
                    match: match,
                    confidence: confidence,
                    debugSummary: "D normalized raster template"
                )
            )
        }

        return candidates
    }

    private static func bTemplateConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let occupiedCells = occupiedGridCells(from: sample.normalizedStrokes)
        guard occupiedCells.count >= 8 else {
            return nil
        }

        let leftCells = occupiedCells.filter { coordinates(for: $0).x <= 2 }
        let waistCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return (2...5).contains(coordinates.x) && (3...5).contains(coordinates.y)
        }
        let upperRightCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 5 && coordinates.y <= 3
        }
        let lowerRightCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 5 && coordinates.y >= 5
        }
        let rightCells = occupiedCells.filter { coordinates(for: $0).x >= 6 }
        let leftVerticalRecall = Double(Set(leftCells.map { coordinates(for: $0).y }).count) / Double(gridSize)
        let totalCells = max(1, occupiedCells.count)
        let waistCoverage = Double(waistCells.count) / Double(totalCells)
        let rightCoverage = Double(rightCells.count) / Double(totalCells)

        let leftStemScore = min(1.0, leftVerticalRecall / 0.58) * 0.24
        let waistScore = min(1.0, Double(waistCells.count) / 3.0) * 0.24
        let upperRightScore = min(1.0, Double(upperRightCells.count) / 4.0) * 0.18
        let lowerRightScore = min(1.0, Double(lowerRightCells.count) / 4.0) * 0.18
        let rightCoverageScore = min(1.0, rightCoverage / 0.22) * 0.10
        let compactnessScore = min(1.0, Double(occupiedCells.count) / 28.0) * 0.06
        let confidence = max(0, min(0.84, 0.08
            + leftStemScore
            + waistScore
            + upperRightScore
            + lowerRightScore
            + rightCoverageScore
            + compactnessScore))

        guard leftVerticalRecall >= 0.50,
              waistCells.count >= 2,
              waistCoverage >= 0.04,
              upperRightCells.count >= 2,
              lowerRightCells.count >= 2,
              rightCoverage >= 0.16,
              confidence >= 0.68 else {
            return nil
        }

        return confidence
    }

    private static func cTemplateConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let occupiedCells = occupiedGridCells(from: sample.normalizedStrokes)
        guard occupiedCells.count >= 5 else {
            return nil
        }

        let matchedTemplateCells = cTemplateCells.intersection(occupiedCells).count
        let templateRecall = Double(matchedTemplateCells) / Double(cTemplateCells.count)
        let leftCells = occupiedCells.filter { coordinates(for: $0).x <= 2 }.count
        let topCells = occupiedCells.filter { coordinates(for: $0).y <= 2 }.count
        let bottomCells = occupiedCells.filter { coordinates(for: $0).y >= 6 }.count
        let rightMiddleCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 6 && (3...5).contains(coordinates.y)
        }.count
        let totalCells = max(1, occupiedCells.count)
        let leftCoverage = Double(leftCells) / Double(totalCells)
        let topCoverage = Double(topCells) / Double(totalCells)
        let bottomCoverage = Double(bottomCells) / Double(totalCells)
        let rightMiddlePenalty = min(0.32, Double(rightMiddleCells) * 0.12)
        let regionScore = min(1, leftCoverage / 0.28) * 0.32
            + min(1, topCoverage / 0.24) * 0.18
            + min(1, bottomCoverage / 0.24) * 0.18
            + (1 - min(1, Double(rightMiddleCells) / 2.0)) * 0.18
        let confidence = max(0, min(0.84, 0.18 + templateRecall * 0.24 + regionScore - rightMiddlePenalty))

        guard leftCoverage >= 0.18,
              topCoverage >= 0.12,
              bottomCoverage >= 0.12,
              rightMiddleCells <= 1,
              confidence >= 0.62 else {
            return nil
        }

        return confidence
    }

    private static func dTemplateConfidence(_ sample: ChordRecognitionInkSample) -> Double? {
        let occupiedCells = occupiedGridCells(from: sample.normalizedStrokes)
        guard occupiedCells.count >= 7 else {
            return nil
        }

        let leftCells = occupiedCells.filter { coordinates(for: $0).x <= 2 }
        let topCells = occupiedCells.filter { coordinates(for: $0).y <= 2 }
        let bottomCells = occupiedCells.filter { coordinates(for: $0).y >= 6 }
        let rightCells = occupiedCells.filter { coordinates(for: $0).x >= 6 }
        let rightMiddleCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 6 && (2...6).contains(coordinates.y)
        }
        let rightTopCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 5 && coordinates.y <= 2
        }
        let rightBottomCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return coordinates.x >= 5 && coordinates.y >= 6
        }
        let leftYValues = Set(leftCells.map { coordinates(for: $0).y })
        let leftVerticalRecall = Double(leftYValues.count) / Double(gridSize)
        let totalCells = max(1, occupiedCells.count)
        let rightCoverage = Double(rightCells.count) / Double(totalCells)
        let rightMiddleCoverage = Double(rightMiddleCells.count) / Double(totalCells)
        let waistCells = occupiedCells.filter { cell in
            let coordinates = coordinates(for: cell)
            return (2...5).contains(coordinates.x) && (3...5).contains(coordinates.y)
        }

        let leftStemScore = min(1.0, leftVerticalRecall / 0.55) * 0.28
        let rightTopScore = min(1.0, Double(rightTopCells.count) / 2.0) * 0.16
        let rightMiddleScore = min(1.0, Double(rightMiddleCells.count) / 3.0) * 0.20
        let rightBottomScore = min(1.0, Double(rightBottomCells.count) / 1.0) * 0.10
        let topScore = min(1.0, Double(topCells.count) / 4.0) * 0.10
        let bottomScore = min(1.0, Double(bottomCells.count) / 3.0) * 0.10
        let rightCoverageScore = min(1.0, rightCoverage / 0.20) * 0.06
        let regionScore = leftStemScore
            + rightTopScore
            + rightMiddleScore
            + rightBottomScore
            + topScore
            + bottomScore
            + rightCoverageScore
        let confidence = max(0, min(0.84, 0.10 + regionScore))

        guard leftVerticalRecall >= 0.45,
              rightCoverage >= 0.14,
              rightMiddleCoverage >= 0.09,
              rightTopCells.count >= 1,
              rightBottomCells.count >= 1,
              waistCells.count <= 1,
              confidence >= 0.66 else {
            return nil
        }

        return confidence
    }

    private static func occupiedGridCells(from normalizedStrokes: [[CGPoint]]) -> Set<Int> {
        var occupiedCells: Set<Int> = []

        for stroke in normalizedStrokes {
            guard let firstPoint = stroke.first else {
                continue
            }

            occupiedCells.insert(cell(for: firstPoint))
            for segment in zip(stroke, stroke.dropFirst()) {
                let segmentLength = hypot(segment.1.x - segment.0.x, segment.1.y - segment.0.y)
                let steps = max(1, Int(ceil(segmentLength * CGFloat(gridSize) * 2)))
                for step in 0...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let point = CGPoint(
                        x: segment.0.x + (segment.1.x - segment.0.x) * t,
                        y: segment.0.y + (segment.1.y - segment.0.y) * t
                    )
                    occupiedCells.insert(cell(for: point))
                }
            }
        }

        return occupiedCells
    }

    private static func cell(for point: CGPoint) -> Int {
        let x = min(gridSize - 1, max(0, Int((point.x * CGFloat(gridSize)).rounded(.down))))
        let y = min(gridSize - 1, max(0, Int((point.y * CGFloat(gridSize)).rounded(.down))))
        return index(x: x, y: y)
    }

    private static func index(x: Int, y: Int) -> Int {
        y * gridSize + x
    }

    private static func coordinates(for index: Int) -> (x: Int, y: Int) {
        (index % gridSize, index / gridSize)
    }
}
