import Foundation

struct ChordEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var symbol: ChordSymbol
    var startPosition: BeatPosition
    var duration: RhythmValue
    var rhythmPlacement: RhythmPlacement
    var mappedRhythmSlotIndex: Int? = nil
    var tieOut: Bool
    var hitStyle: HitStyle
    var rawInput: String?

    var displaySummary: String {
        var components = [symbol.displayText, "@\(startPosition.displayText)", duration.displayText]

        if hitStyle != .none {
            components.append(hitStyle.rawValue)
        }

        if let mappedRhythmSlotIndex {
            components.append("slot \(mappedRhythmSlotIndex + 1)")
        }

        if tieOut {
            components.append("tie out")
        }

        return components.joined(separator: " · ")
    }

    func transposed(for view: TranspositionView) -> ChordEvent {
        var copy = self
        copy.symbol = symbol.transposed(by: view.semitoneOffsetFromConcert)
        return copy
    }
}

struct ChordSymbol: Codable, Hashable {
    var root: ChordRoot
    var accidental: Accidental
    var quality: String
    var extensions: [String]
    var alterations: [String]
    var slashBass: String?

    var displayText: String {
        let extensionText = extensions.joined()
        let alterationText = alterations.joined()
        let slashText = slashBass.map { "/\($0)" } ?? ""

        return "\(root.rawValue)\(accidental.rawValue)\(quality)\(extensionText)\(alterationText)\(slashText)"
    }

    func transposed(by semitones: Int) -> ChordSymbol {
        let originalPitch = ChordPitch(root: root, accidental: accidental)
        let preference = PitchSpellingPreference.forAccidental(accidental)
        let transposedRoot = originalPitch.transposed(by: semitones).spelled(using: preference)

        var copy = self
        copy.root = transposedRoot.root
        copy.accidental = transposedRoot.accidental

        if let slashBass,
           let parsedBass = ChordPitch.parse(slashBass) {
            let transposedBass = parsedBass.transposed(by: semitones).spelled(using: preference)
            copy.slashBass = transposedBass.displayText
        }

        return copy
    }
}

enum ChordRoot: String, Codable, CaseIterable, Hashable {
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"
    case g = "G"
    case a = "A"
    case b = "B"
}

enum Accidental: String, Codable, CaseIterable, Hashable {
    case natural = ""
    case sharp = "#"
    case flat = "b"
}
