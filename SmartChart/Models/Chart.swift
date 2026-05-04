import Foundation

struct Chart: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var composerCredit: String?
    var styleNote: String?
    var chartType: ChartType
    var documentKey: DocumentKey
    var documentFont: ChartFontPreset
    var notationFont: NotationFontPreset
    var defaultTranspositionView: TranspositionView
    var defaultMeter: Meter
    var staffStyle: StaffStyle = .fiveLine
    var hasCompletedInitialSetup: Bool = true
    var systems: [ChartSystem]
    var timeSignatureChanges: [TimeSignatureChange]
    var sectionLabels: [SectionLabel]
    var cueTexts: [CueText]
    var roadmapObjects: [RoadmapObject]
    var stylePreset: StylePreset
    var engravingPreset: EngravingPreset
    var pageHandwrittenNotationData: Data?
    var pageHandwrittenChordData: Data?
    var createdAt: Date
    var updatedAt: Date

    var measures: [Measure] {
        systems.flatMap(\.measures)
    }

    init(
        id: UUID,
        title: String,
        composerCredit: String? = nil,
        styleNote: String? = nil,
        chartType: ChartType,
        documentKey: DocumentKey,
        documentFont: ChartFontPreset,
        notationFont: NotationFontPreset = .petaluma,
        defaultTranspositionView: TranspositionView,
        defaultMeter: Meter,
        staffStyle: StaffStyle = .fiveLine,
        hasCompletedInitialSetup: Bool = true,
        systems: [ChartSystem],
        timeSignatureChanges: [TimeSignatureChange] = [],
        sectionLabels: [SectionLabel],
        cueTexts: [CueText],
        roadmapObjects: [RoadmapObject],
        stylePreset: StylePreset,
        engravingPreset: EngravingPreset = .balanced,
        pageHandwrittenNotationData: Data? = nil,
        pageHandwrittenChordData: Data? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.composerCredit = composerCredit
        self.styleNote = styleNote
        self.chartType = chartType
        self.documentKey = documentKey
        self.documentFont = documentFont
        self.notationFont = notationFont
        self.defaultTranspositionView = defaultTranspositionView
        self.defaultMeter = defaultMeter
        self.staffStyle = staffStyle
        self.hasCompletedInitialSetup = hasCompletedInitialSetup
        self.systems = systems
        self.timeSignatureChanges = timeSignatureChanges
        self.sectionLabels = sectionLabels
        self.cueTexts = cueTexts
        self.roadmapObjects = roadmapObjects
        self.stylePreset = stylePreset
        self.engravingPreset = engravingPreset
        self.pageHandwrittenNotationData = pageHandwrittenNotationData
        self.pageHandwrittenChordData = pageHandwrittenChordData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case composerCredit
        case styleNote
        case chartType
        case documentKey
        case documentFont
        case notationFont
        case defaultTranspositionView
        case defaultMeter
        case staffStyle
        case hasCompletedInitialSetup
        case systems
        case timeSignatureChanges
        case sectionLabels
        case cueTexts
        case roadmapObjects
        case stylePreset
        case engravingPreset
        case pageHandwrittenNotationData
        case pageHandwrittenChordData
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        composerCredit = try container.decodeIfPresent(String.self, forKey: .composerCredit)
        styleNote = try container.decodeIfPresent(String.self, forKey: .styleNote)
        chartType = try container.decode(ChartType.self, forKey: .chartType)
        documentKey = try container.decode(DocumentKey.self, forKey: .documentKey)
        documentFont = try container.decode(ChartFontPreset.self, forKey: .documentFont)
        notationFont = try container.decodeIfPresent(NotationFontPreset.self, forKey: .notationFont) ?? .petaluma
        defaultTranspositionView = try container.decode(TranspositionView.self, forKey: .defaultTranspositionView)
        defaultMeter = try container.decode(Meter.self, forKey: .defaultMeter)
        staffStyle = try container.decodeIfPresent(StaffStyle.self, forKey: .staffStyle) ?? .fiveLine
        hasCompletedInitialSetup = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialSetup) ?? true
        systems = try container.decode([ChartSystem].self, forKey: .systems)
        timeSignatureChanges = try container.decodeIfPresent([TimeSignatureChange].self, forKey: .timeSignatureChanges) ?? []
        sectionLabels = try container.decode([SectionLabel].self, forKey: .sectionLabels)
        cueTexts = try container.decode([CueText].self, forKey: .cueTexts)
        roadmapObjects = try container.decode([RoadmapObject].self, forKey: .roadmapObjects)
        stylePreset = try container.decode(StylePreset.self, forKey: .stylePreset)
        engravingPreset = try container.decodeIfPresent(EngravingPreset.self, forKey: .engravingPreset) ?? .balanced
        pageHandwrittenNotationData = try container.decodeIfPresent(Data.self, forKey: .pageHandwrittenNotationData)
        pageHandwrittenChordData = try container.decodeIfPresent(Data.self, forKey: .pageHandwrittenChordData)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
        guard view.semitoneOffsetFromConcert != 0 else { return self }

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

enum StaffStyle: String, Codable, Hashable {
    case fiveLine
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
