import Foundation

struct Chart: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var chartType: ChartType
    var documentKey: DocumentKey
    var documentFont: ChartFontPreset
    var defaultTranspositionView: TranspositionView
    var defaultMeter: Meter
    var systems: [ChartSystem]
    var sectionLabels: [SectionLabel]
    var cueTexts: [CueText]
    var roadmapObjects: [RoadmapObject]
    var stylePreset: StylePreset
    var createdAt: Date
    var updatedAt: Date

    var measures: [Measure] {
        systems.flatMap(\.measures)
    }
}

struct ChartSystem: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var spacingMode: SpacingMode
    var lineBreakRule: LineBreakRule
    var measures: [Measure]
}

enum ChartType: String, Codable, CaseIterable, Hashable {
    case chordChart
    case roadmapChart
    case teachingChart
}

struct DocumentKey: Codable, Hashable {
    var tonic: ChordRoot
    var accidental: Accidental
    var mode: KeyMode

    var displayText: String {
        "\(tonic.rawValue)\(accidental.rawValue) \(mode.displayText)"
    }

    func transposed(for view: TranspositionView) -> DocumentKey {
        let pitch = ChordPitch(root: tonic, accidental: accidental)
        let preference = PitchSpellingPreference.forAccidental(accidental)
        let transposedPitch = pitch.transposed(by: view.semitoneOffsetFromConcert).spelled(using: preference)

        return DocumentKey(
            tonic: transposedPitch.root,
            accidental: transposedPitch.accidental,
            mode: mode
        )
    }
}

enum KeyMode: String, Codable, CaseIterable, Hashable {
    case major
    case minor
    case modal

    var displayText: String {
        switch self {
        case .major:
            return "major"
        case .minor:
            return "minor"
        case .modal:
            return "modal"
        }
    }
}

enum TranspositionView: String, Codable, CaseIterable, Hashable {
    case concert
    case bb
    case eb

    var displayText: String {
        switch self {
        case .concert:
            return "Concert"
        case .bb:
            return "Bb"
        case .eb:
            return "Eb"
        }
    }

    var semitoneOffsetFromConcert: Int {
        switch self {
        case .concert:
            return 0
        case .bb:
            return 2
        case .eb:
            return 9
        }
    }
}

enum ChartFontPreset: String, Codable, CaseIterable, Hashable {
    case classic
    case rounded
    case serif
    case mono

    var displayText: String {
        switch self {
        case .classic:
            return "Classic"
        case .rounded:
            return "Rounded"
        case .serif:
            return "Serif"
        case .mono:
            return "Mono"
        }
    }
}

enum StylePreset: String, Codable, CaseIterable, Hashable {
    case cleanStudio
    case gigSheet
    case rehearsalDraft
}

enum SpacingMode: String, Codable, CaseIterable, Hashable {
    case automatic
    case relaxed
    case compact
}

enum LineBreakRule: String, Codable, CaseIterable, Hashable {
    case automatic
    case forced
    case keepWithNext
}
