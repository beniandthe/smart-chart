import Foundation

struct ChordRecognitionMatch: Hashable {
    var rawInput: String
    var symbol: ChordSymbol

    var displayText: String {
        symbol.displayText
    }
}

typealias BasicMajorChordMatch = ChordRecognitionMatch

enum ChordRecognitionCompendium {
    static let recognitionWords: [String] = entries.flatMap(\.aliases)
    static var supportedMatches: [ChordRecognitionMatch] {
        entries.map { entry in
            ChordRecognitionMatch(
                rawInput: entry.aliases.first ?? entry.symbol.displayText,
                symbol: entry.symbol
            )
        }
    }

    static func match(_ text: String) -> ChordRecognitionMatch? {
        guard !usesUnsupportedMajorSuffix(text) else {
            return nil
        }

        let normalizedInput = normalized(text)
        guard let entry = entries.first(where: { entry in
            entry.normalizedAliases.contains(normalizedInput)
        }) else {
            return nil
        }

        return ChordRecognitionMatch(rawInput: text, symbol: entry.symbol)
    }

    static func match(candidates: [String]) -> ChordRecognitionMatch? {
        for candidate in candidates {
            if let match = match(candidate) {
                return match
            }
        }

        return nil
    }

    fileprivate static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "＃", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "FLAT", with: "b")
            .replacingOccurrences(of: "SHARP", with: "#")
            .filter { character in
                character.isLetter || character.isNumber || character == "#" || character == "-"
            }
            .uppercased()
    }

    private static func usesUnsupportedMajorSuffix(_ text: String) -> Bool {
        let normalizedInput = normalized(text)
        let rootSpellings = baseEntries
            .map { normalized($0.displayText) }
            .sorted { $0.count > $1.count }
        guard let rootSpelling = rootSpellings.first(where: { normalizedInput.hasPrefix($0) }) else {
            return false
        }

        let suffix = String(normalizedInput.dropFirst(rootSpelling.count))
        guard !suffix.isEmpty else {
            return false
        }

        if suffix == "M",
           text.contains("M"),
           !text.contains("m") {
            return true
        }

        return suffix == "MAJ" || suffix == "MAJOR"
    }

    private static let entries: [ChordRecognitionEntry] = baseEntries.flatMap { entry in
        [entry, entry.minorEntry]
    }

    private static let baseEntries: [ChordRecognitionEntry] = [
        ChordRecognitionEntry(root: .c, accidental: .natural, aliases: ["C"]),
        ChordRecognitionEntry(root: .c, accidental: .sharp, aliases: ["C#", "C sharp"]),
        ChordRecognitionEntry(root: .c, accidental: .flat, aliases: ["Cb", "C flat"]),
        ChordRecognitionEntry(root: .d, accidental: .natural, aliases: ["D"]),
        ChordRecognitionEntry(root: .d, accidental: .sharp, aliases: ["D#", "D sharp"]),
        ChordRecognitionEntry(root: .d, accidental: .flat, aliases: ["Db", "D flat"]),
        ChordRecognitionEntry(root: .e, accidental: .natural, aliases: ["E"]),
        ChordRecognitionEntry(root: .e, accidental: .sharp, aliases: ["E#", "E sharp"]),
        ChordRecognitionEntry(root: .e, accidental: .flat, aliases: ["Eb", "E flat"]),
        ChordRecognitionEntry(root: .f, accidental: .natural, aliases: ["F"]),
        ChordRecognitionEntry(root: .f, accidental: .sharp, aliases: ["F#", "F sharp"]),
        ChordRecognitionEntry(root: .f, accidental: .flat, aliases: ["Fb", "F flat"]),
        ChordRecognitionEntry(root: .g, accidental: .natural, aliases: ["G"]),
        ChordRecognitionEntry(root: .g, accidental: .sharp, aliases: ["G#", "G sharp"]),
        ChordRecognitionEntry(root: .g, accidental: .flat, aliases: ["Gb", "G flat"]),
        ChordRecognitionEntry(root: .a, accidental: .natural, aliases: ["A"]),
        ChordRecognitionEntry(root: .a, accidental: .sharp, aliases: ["A#", "A sharp"]),
        ChordRecognitionEntry(root: .a, accidental: .flat, aliases: ["Ab", "A flat"]),
        ChordRecognitionEntry(root: .b, accidental: .natural, aliases: ["B"]),
        ChordRecognitionEntry(root: .b, accidental: .sharp, aliases: ["B#", "B sharp"]),
        ChordRecognitionEntry(root: .b, accidental: .flat, aliases: ["Bb", "B flat"])
    ]
}

enum BasicMajorChordCompendium {
    static let recognitionWords = ChordRecognitionCompendium.recognitionWords
    static var supportedMatches: [BasicMajorChordMatch] {
        ChordRecognitionCompendium.supportedMatches
    }

    static func match(_ text: String) -> BasicMajorChordMatch? {
        ChordRecognitionCompendium.match(text)
    }

    static func match(candidates: [String]) -> BasicMajorChordMatch? {
        ChordRecognitionCompendium.match(candidates: candidates)
    }
}

private struct ChordRecognitionEntry: Hashable {
    var root: ChordRoot
    var accidental: Accidental
    var quality: String = ""
    var aliases: [String]

    var symbol: ChordSymbol {
        ChordSymbol(
            root: root,
            accidental: accidental,
            quality: quality,
            extensions: [],
            alterations: [],
            slashBass: nil
        )
    }

    var displayText: String {
        symbol.displayText
    }

    var minorEntry: ChordRecognitionEntry {
        ChordRecognitionEntry(
            root: root,
            accidental: accidental,
            quality: "-",
            aliases: minorAliases
        )
    }

    var normalizedAliases: Set<String> {
        Set(aliases.map(ChordRecognitionCompendium.normalized))
    }

    private var minorAliases: [String] {
        let base = displayText
        return aliases.flatMap { alias in
            [
                "\(alias)-",
                "\(alias)m",
                "\(alias)min",
                "\(alias) minor"
            ]
        } + [
            "\(base)-",
            "\(base)m",
            "\(base)min",
            "\(base) minor"
        ]
    }
}
