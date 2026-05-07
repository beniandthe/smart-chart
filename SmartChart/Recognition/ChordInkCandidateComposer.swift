import Foundation

struct ChordInkCandidate: Hashable {
    var text: String
    var confidence: Double
    var glyphCandidates: [GlyphCandidate]
}

struct ChordInkCandidateComposerConfiguration: Hashable {
    var maxAlternativesPerCluster: Int
    var maxCandidateCount: Int
    var maxGeneratedSequences: Int

    static let chordSymbols = ChordInkCandidateComposerConfiguration(
        maxAlternativesPerCluster: 3,
        maxCandidateCount: 32,
        maxGeneratedSequences: 512
    )
}

struct ChordInkCandidateComposer {
    var configuration: ChordInkCandidateComposerConfiguration

    init(configuration: ChordInkCandidateComposerConfiguration = .chordSymbols) {
        self.configuration = configuration
    }

    func compose(glyphCandidates columns: [[GlyphCandidate]]) -> [ChordInkCandidate] {
        let candidateColumns = columns
            .map { column in
                Array(column.sortedByConfidence.prefix(configuration.maxAlternativesPerCluster))
            }
            .filter { !$0.isEmpty }

        guard !candidateColumns.isEmpty else {
            return []
        }

        var bestCandidatesByText: [String: ChordInkCandidate] = [:]
        var generatedSequenceCount = 0

        for prefixLength in 1...candidateColumns.count {
            let prefixColumns = Array(candidateColumns.prefix(prefixLength))
            for sequence in candidateSequences(from: prefixColumns) {
                guard generatedSequenceCount < configuration.maxGeneratedSequences else {
                    break
                }

                generatedSequenceCount += 1

                for variant in textVariants(for: sequence) {
                    let confidence = score(
                        text: variant,
                        glyphCandidates: sequence,
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

        return Array(bestCandidatesByText.values)
            .sortedByConfidence
            .prefix(configuration.maxCandidateCount)
            .map { $0 }
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

        return Array(Set(variants)).sorted()
    }

    private func glyphTextVariants(for text: String) -> [String] {
        switch text {
        case "Δ", "∆":
            return ["△"]
        case "m", "-":
            return ["-", "m"]
        default:
            return [text]
        }
    }

    private func score(
        text: String,
        glyphCandidates: [GlyphCandidate],
        totalClusterCount: Int
    ) -> Double {
        let averageGlyphConfidence = glyphCandidates
            .map(\.confidence)
            .reduce(0, +) / Double(max(glyphCandidates.count, 1))
        var score = averageGlyphConfidence

        if startsWithRoot(text) {
            score += 1.0
        } else {
            score -= 1.0
        }

        if parsesAsChord(text) {
            score += 2.0
        } else {
            score -= 0.25
        }

        if hasAccidentalImmediatelyAfterRoot(text) {
            score += 0.25
        }

        if hasValidSlashBass(text) {
            score += 0.85
        } else if text.contains("/") {
            score -= 0.75
        }

        if hasTriangleMajorQuality(text) {
            score += 0.15
        }

        // Prefer candidates that explain more of the written glyphs, so F# wins over
        // the F prefix when a nearby sharp has reasonable confidence.
        score += Double(max(0, glyphCandidates.count - 1)) * 0.12
        score -= Double(max(0, totalClusterCount - glyphCandidates.count)) * 0.45

        return score
    }

    private func startsWithRoot(_ text: String) -> Bool {
        guard let first = text.first else {
            return false
        }

        return "ABCDEFG".contains(first)
    }

    private func parsesAsChord(_ text: String) -> Bool {
        (try? ChordSymbolParser.parse(text)) != nil
    }

    private func hasAccidentalImmediatelyAfterRoot(_ text: String) -> Bool {
        guard text.count > 1 else {
            return false
        }

        let secondIndex = text.index(after: text.startIndex)
        return text[secondIndex] == "#" || text[secondIndex] == "b"
    }

    private func hasValidSlashBass(_ text: String) -> Bool {
        let pieces = text.split(separator: "/", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else {
            return false
        }

        return ChordPitch.parse(pieces[1]) != nil
    }

    private func hasTriangleMajorQuality(_ text: String) -> Bool {
        text.contains("△") || text.contains("Δ") || text.contains("∆")
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
