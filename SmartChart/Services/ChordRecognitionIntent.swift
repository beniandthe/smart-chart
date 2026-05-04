import Foundation

enum ChordRecognitionComponent: String, Hashable {
    case root
    case accidental
    case quality
    case `extension`
    case alteration
    case slashBass
}

enum ChordRecognitionEvidenceSource: String, Hashable {
    case text
    case visualRoot
    case visualAccidental
    case visualQuality
    case learnedExample
    case learnedBoundary
    case rasterTemplate
}

struct ChordRecognitionStructuralEvidence: Hashable {
    private var sourcesByComponent: [ChordRecognitionComponent: Set<ChordRecognitionEvidenceSource>]

    init(
        sourcesByComponent: [ChordRecognitionComponent: Set<ChordRecognitionEvidenceSource>] = [:]
    ) {
        self.sourcesByComponent = sourcesByComponent
    }

    static func merge(
        _ evidences: [ChordRecognitionStructuralEvidence]
    ) -> ChordRecognitionStructuralEvidence {
        evidences.reduce(ChordRecognitionStructuralEvidence()) { partialResult, evidence in
            partialResult.merged(with: evidence)
        }
    }

    func supportsRoot(for symbol: ChordSymbol) -> Bool {
        supports(.root)
    }

    func supportsAccidental(for symbol: ChordSymbol) -> Bool {
        symbol.accidental == .natural || supports(.accidental)
    }

    func supportsQuality(for symbol: ChordSymbol) -> Bool {
        symbol.quality != "-" || supports(.quality)
    }

    func supports(_ component: ChordRecognitionComponent) -> Bool {
        !(sourcesByComponent[component] ?? []).isEmpty
    }

    func sources(for component: ChordRecognitionComponent) -> Set<ChordRecognitionEvidenceSource> {
        sourcesByComponent[component] ?? []
    }

    func adding(
        _ component: ChordRecognitionComponent,
        source: ChordRecognitionEvidenceSource
    ) -> ChordRecognitionStructuralEvidence {
        var nextSources = sourcesByComponent
        nextSources[component, default: []].insert(source)
        return ChordRecognitionStructuralEvidence(sourcesByComponent: nextSources)
    }

    private func merged(
        with evidence: ChordRecognitionStructuralEvidence
    ) -> ChordRecognitionStructuralEvidence {
        var nextSources = sourcesByComponent
        for (component, sources) in evidence.sourcesByComponent {
            nextSources[component, default: []].formUnion(sources)
        }
        return ChordRecognitionStructuralEvidence(sourcesByComponent: nextSources)
    }
}

enum ChordRecognitionDecisionPolicy {
    static let isConfirmationFirstEnabled = true

    static func shouldAppendAutomatically(
        report: ChordRecognitionReport,
        userRequiresConfirmation: Bool
    ) -> Bool {
        guard !isConfirmationFirstEnabled else {
            return false
        }

        return !userRequiresConfirmation && report.shouldAutoAcceptBestCandidate
    }

    static func requiresConfirmation(
        report: ChordRecognitionReport,
        userRequiresConfirmation: Bool
    ) -> Bool {
        guard report.bestCandidate != nil else {
            return false
        }

        return userRequiresConfirmation || !shouldAppendAutomatically(
            report: report,
            userRequiresConfirmation: userRequiresConfirmation
        )
    }
}

enum ChordRecognitionIntentAudit {
    static func summary(
        for report: ChordRecognitionReport
    ) -> String {
        guard let bestCandidate = report.bestCandidate else {
            return "no best candidate"
        }

        let symbol = bestCandidate.match.symbol
        let root = symbol.root.rawValue
        let accidental = symbol.accidental == .natural ? "natural" : symbol.accidental.rawValue
        let quality = symbol.quality == "-" ? "minor" : "major"
        let evidence = evidenceFlags(
            for: bestCandidate,
            in: report.candidates
        )

        return [
            "symbol=\(bestCandidate.match.displayText)",
            "root=\(root)",
            "accidental=\(accidental)",
            "quality=\(quality)",
            "rootEvidence=\(evidence.hasRootEvidence)",
            "accidentalEvidence=\(evidence.hasAccidentalEvidence)",
            "minorEvidence=\(evidence.hasMinorEvidence)"
        ].joined(separator: " ")
    }

    static func warnings(
        for report: ChordRecognitionReport
    ) -> [String] {
        guard let bestCandidate = report.bestCandidate else {
            return ["noCandidate"]
        }

        let evidence = evidenceFlags(
            for: bestCandidate,
            in: report.candidates
        )
        var warnings: [String] = []
        let symbol = bestCandidate.match.symbol

        if !evidence.hasRootEvidence {
            warnings.append("missingRootEvidence")
        }

        if symbol.accidental != .natural,
           !evidence.hasAccidentalEvidence {
            warnings.append("missingAccidentalEvidence")
        }

        if symbol.quality == "-",
           !evidence.hasMinorEvidence {
            warnings.append("missingMinorEvidence")
        }

        if bestCandidate.method == .confirmedExample,
           evidence.hasRootEvidence == false || (symbol.accidental != .natural && evidence.hasAccidentalEvidence == false) {
            warnings.append("wholeSymbolLearnedMatchWithoutStructure")
        }

        return warnings
    }

    private static func evidenceFlags(
        for candidate: ChordRecognitionCandidate,
        in candidates: [ChordRecognitionCandidate]
    ) -> ChordRecognitionIntentEvidence {
        let symbol = candidate.match.symbol
        let sameRootCandidates = candidates.filter { otherCandidate in
            otherCandidate.match.symbol.root == symbol.root
        }
        let sameSymbolCandidates = candidates.filter { otherCandidate in
            otherCandidate.match.displayText == candidate.match.displayText
        }
        let rootEvidence = ChordRecognitionStructuralEvidence.merge(
            sameRootCandidates.map(\.structuralEvidence)
        )
        let symbolEvidence = ChordRecognitionStructuralEvidence.merge(
            sameSymbolCandidates.map(\.structuralEvidence)
        )

        return ChordRecognitionIntentEvidence(
            hasRootEvidence: rootEvidence.supportsRoot(for: symbol),
            hasAccidentalEvidence: symbolEvidence.supportsAccidental(for: symbol),
            hasMinorEvidence: symbolEvidence.supportsQuality(for: symbol)
        )
    }
}

private struct ChordRecognitionIntentEvidence {
    var hasRootEvidence: Bool
    var hasAccidentalEvidence: Bool
    var hasMinorEvidence: Bool
}
