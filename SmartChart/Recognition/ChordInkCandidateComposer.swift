import Foundation

struct ChordInkCandidate: Hashable {
    var text: String
    var confidence: Double
    var glyphCandidates: [GlyphCandidate]
}

struct ChordInkCandidateCompositionResult: Hashable {
    var candidates: [ChordInkCandidate]
    var metrics: ChordInkCandidateCompositionMetrics
}

struct ChordInkCandidateComposerConfiguration: Hashable {
    var maxAlternativesPerCluster: Int
    var maxCandidateCount: Int
    var maxGeneratedSequences: Int
    var scoring: ChordInkCandidateComposerScoring

    static let chordSymbols = ChordInkCandidateComposerConfiguration(
        maxAlternativesPerCluster: 3,
        maxCandidateCount: 32,
        maxGeneratedSequences: 4096,
        scoring: ChordInkCandidateComposerScoring()
    )
}

struct ChordInkCandidateComposer {
    var configuration: ChordInkCandidateComposerConfiguration

    init(configuration: ChordInkCandidateComposerConfiguration = .chordSymbols) {
        self.configuration = configuration
    }

    func compose(glyphCandidates columns: [[GlyphCandidate]]) -> [ChordInkCandidate] {
        composeDetailed(glyphCandidates: columns).candidates
    }

    func composeDetailed(glyphCandidates columns: [[GlyphCandidate]]) -> ChordInkCandidateCompositionResult {
        let sortedColumns = columns.map(\.sortedByConfidence)
        let selectionPolicy = ChordInkCandidateSelectionPolicy(
            maxAlternativesPerCluster: configuration.maxAlternativesPerCluster
        )
        let candidateColumns = sortedColumns.indices
            .map { index in
                selectionPolicy.selectedGlyphCandidates(forColumnAt: index, in: sortedColumns)
            }
            .filter { !$0.isEmpty }

        guard !candidateColumns.isEmpty else {
            return ChordInkCandidateCompositionResult(
                candidates: [],
                metrics: ChordInkCandidateCompositionMetrics(
                    selectedColumnCount: 0,
                    generatedSequenceCount: 0,
                    returnedCandidateCount: 0,
                    maxGeneratedSequences: configuration.maxGeneratedSequences,
                    hitGeneratedSequenceLimit: false
                )
            )
        }

        var bestCandidatesByText: [String: ChordInkCandidate] = [:]
        var generatedSequenceCount = 0
        var hitGeneratedSequenceLimit = false
        let scoringPolicy = ChordInkCandidateScoringPolicy(scoring: configuration.scoring)

        for prefixLength in 1...candidateColumns.count {
            let prefixColumns = Array(candidateColumns.prefix(prefixLength))
            for sequence in candidateSequences(from: prefixColumns) {
                guard generatedSequenceCount < configuration.maxGeneratedSequences else {
                    hitGeneratedSequenceLimit = true
                    break
                }

                generatedSequenceCount += 1

                for variant in textVariants(for: sequence) {
                    let confidence = scoringPolicy.score(
                        text: variant,
                        glyphCandidates: sequence,
                        candidateColumns: candidateColumns,
                        totalClusterCount: candidateColumns.count
                    )
                    let candidate = ChordInkCandidate(
                        text: variant,
                        confidence: confidence,
                        glyphCandidates: sequence
                    )

                    if let currentBest = bestCandidatesByText[variant],
                       currentBest.confidence >= candidate.confidence {
                        continue
                    }

                    bestCandidatesByText[variant] = candidate
                }
            }
        }

        let candidates = Array(bestCandidatesByText.values)
            .sortedByConfidence
            .prefix(configuration.maxCandidateCount)
            .map { $0 }
        return ChordInkCandidateCompositionResult(
            candidates: candidates,
            metrics: ChordInkCandidateCompositionMetrics(
                selectedColumnCount: candidateColumns.count,
                generatedSequenceCount: generatedSequenceCount,
                returnedCandidateCount: candidates.count,
                maxGeneratedSequences: configuration.maxGeneratedSequences,
                hitGeneratedSequenceLimit: hitGeneratedSequenceLimit
            )
        )
    }

    private func candidateSequences(from columns: [[GlyphCandidate]]) -> [[GlyphCandidate]] {
        columns.reduce([[]]) { partialSequences, column in
            partialSequences.flatMap { sequence in
                column.map { candidate in
                    sequence + [candidate]
                }
            }
        }
    }

    private func textVariants(for glyphCandidates: [GlyphCandidate]) -> [String] {
        let variantsByGlyph = glyphCandidates.map { glyphTextVariants(for: $0.text) }
        let variants = variantsByGlyph.reduce([""]) { partialVariants, glyphVariants in
            partialVariants.flatMap { prefix in
                glyphVariants.map { variant in
                    prefix + variant
                }
            }
        }

        let expandedVariants = variants.flatMap { variant in
            var expansions: [String] = []
            if let compactSharpElevenVariant = expandedCompactSharpElevenVariant(for: variant) {
                expansions.append(compactSharpElevenVariant)
            }
            expansions.append(contentsOf: expandedAlteredExtensionTrailingWrapperVariants(for: variant))
            if let slashBassFlatLookalikeVariant = expandedSlashBassFlatLookalikeVariant(for: variant) {
                expansions.append(slashBassFlatLookalikeVariant)
            }
            expansions.append(contentsOf: expandedSharpElevenWrapperVariants(for: variant))
            if let trailingWrapperVariant = expandedSharpElevenTrailingWrapperVariant(for: variant) {
                expansions.append(trailingWrapperVariant)
            }
            return expansions
        }

        let canonicalVariants = (variants + expandedVariants).map(canonicalTextVariant)
        return Array(Set(canonicalVariants)).sorted()
    }

    private func canonicalTextVariant(for text: String) -> String {
        guard let symbol = try? ChordSymbolParser.parse(text),
              symbol.quality == "-",
              symbol.extensions == ["6"],
              symbol.alterations.isEmpty else {
            return text
        }

        return symbol.displayText
    }

    private func expandedCompactSharpElevenVariant(for text: String) -> String? {
        guard let range = text.range(of: "7#1") else {
            return nil
        }

        let suffix = text[range.upperBound...]
        guard suffix.isEmpty || suffix.first == "/" else {
            return nil
        }

        var expandedText = text
        expandedText.replaceSubrange(range, with: "7#11")
        return expandedText
    }

    private func expandedSharpElevenWrapperVariants(for text: String) -> [String] {
        ["71#11", "7b#11", "7C#11"].compactMap { wrapperPattern in
            guard let range = text.range(of: wrapperPattern) else {
                return nil
            }

            var expandedText = text
            expandedText.replaceSubrange(range, with: "7#11")
            return expandedText
        }
        + ["77#11", "73#11", "75#11"].compactMap { wrapperPattern in
            guard let range = text.range(of: wrapperPattern) else {
                return nil
            }

            var expandedText = text
            expandedText.replaceSubrange(range, with: "7#11")
            return expandedText
        }
        + ["71#1", "77#1", "73#1", "75#1"].compactMap { wrapperPattern in
            guard let range = text.range(of: wrapperPattern) else {
                return nil
            }

            var expandedText = text
            expandedText.replaceSubrange(range, with: "7#11")
            return expandedText
        }
    }

    private func expandedSharpElevenTrailingWrapperVariant(for text: String) -> String? {
        guard let range = text.range(of: "7#11") else {
            return nil
        }

        let suffix = text[range.upperBound...]
        guard suffix.count == 1,
              let wrapper = suffix.first,
              "3579C)".contains(wrapper) else {
            return nil
        }

        return String(text[..<range.upperBound])
    }

    private func expandedAlteredExtensionTrailingWrapperVariants(for text: String) -> [String] {
        ["7#9"].compactMap { alterationPattern in
            guard let range = text.range(of: alterationPattern) else {
                return nil
            }

            let suffix = text[range.upperBound...]
            guard suffix.count == 1,
                  let wrapper = suffix.first,
                  "13579C)".contains(wrapper) else {
                return nil
            }

            return String(text[..<range.upperBound])
        }
    }

    private func expandedSlashBassFlatLookalikeVariant(for text: String) -> String? {
        guard let slashIndex = text.firstIndex(of: "/") else {
            return nil
        }

        let suffixStart = text.index(after: slashIndex)
        guard suffixStart < text.endIndex else {
            return nil
        }

        let suffix = text[suffixStart...]
        guard suffix.count == 2,
              let bassRoot = suffix.first,
              let flatLookalike = suffix.last,
              "ABCDEFG".contains(bassRoot),
              flatLookalike == "G" else {
            return nil
        }

        return String(text[..<slashIndex]) + "/" + String(bassRoot) + "b"
    }

    private func glyphTextVariants(for text: String) -> [String] {
        switch text {
        case "Δ", "∆":
            return ["△"]
        case "º":
            return ["°"]
        case "Ø", "⌀":
            return ["ø"]
        case "°":
            return ["°"]
        case "ø":
            return ["ø"]
        case "m", "-":
            return ["-", "m"]
        default:
            return [text]
        }
    }

}

private extension Array where Element == GlyphCandidate {
    var sortedByConfidence: [GlyphCandidate] {
        sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }

            return lhs.text < rhs.text
        }
    }
}

private extension Array where Element == ChordInkCandidate {
    var sortedByConfidence: [ChordInkCandidate] {
        sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }

            return lhs.text < rhs.text
        }
    }
}
