import CoreGraphics
import Foundation

enum MeasureAuthoringState: String, Codable, Hashable {
    case open
    case committed
}

struct Measure: Identifiable, Codable, Hashable {
    static let minimumManualLayoutWidth: CGFloat = 96
    static let maximumManualLayoutWidth: CGFloat = 420

    var id: UUID
    var index: Int
    var meterOverride: Meter?
    var beatGridPreset: BeatGridPreset
    var rhythmMap: MeasureRhythmMap? = nil
    var manualLayoutWidth: Double? = nil
    var barlineAfter: BarlineType
    var chordEvents: [ChordEvent]
    var cueTextIDs: [UUID]
    var roadmapObjectIDs: [UUID]
    var authoringState: MeasureAuthoringState

    init(
        id: UUID,
        index: Int,
        meterOverride: Meter?,
        beatGridPreset: BeatGridPreset,
        rhythmMap: MeasureRhythmMap? = nil,
        manualLayoutWidth: Double? = nil,
        barlineAfter: BarlineType,
        chordEvents: [ChordEvent],
        cueTextIDs: [UUID],
        roadmapObjectIDs: [UUID],
        authoringState: MeasureAuthoringState = .committed
    ) {
        self.id = id
        self.index = index
        self.meterOverride = meterOverride
        self.beatGridPreset = beatGridPreset
        self.rhythmMap = rhythmMap
        self.manualLayoutWidth = manualLayoutWidth
        self.barlineAfter = barlineAfter
        self.chordEvents = chordEvents
        self.cueTextIDs = cueTextIDs
        self.roadmapObjectIDs = roadmapObjectIDs
        self.authoringState = authoringState
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case index
        case meterOverride
        case beatGridPreset
        case rhythmMap
        case manualLayoutWidth
        case barlineAfter
        case chordEvents
        case cueTextIDs
        case roadmapObjectIDs
        case authoringState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        index = try container.decode(Int.self, forKey: .index)
        meterOverride = try container.decodeIfPresent(Meter.self, forKey: .meterOverride)
        beatGridPreset = try container.decode(BeatGridPreset.self, forKey: .beatGridPreset)
        rhythmMap = try container.decodeIfPresent(MeasureRhythmMap.self, forKey: .rhythmMap)
        manualLayoutWidth = try container.decodeIfPresent(Double.self, forKey: .manualLayoutWidth)
        barlineAfter = try container.decode(BarlineType.self, forKey: .barlineAfter)
        chordEvents = try container.decode([ChordEvent].self, forKey: .chordEvents)
        cueTextIDs = try container.decode([UUID].self, forKey: .cueTextIDs)
        roadmapObjectIDs = try container.decode([UUID].self, forKey: .roadmapObjectIDs)
        authoringState = try container.decodeIfPresent(MeasureAuthoringState.self, forKey: .authoringState) ?? .committed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(index, forKey: .index)
        try container.encodeIfPresent(meterOverride, forKey: .meterOverride)
        try container.encode(beatGridPreset, forKey: .beatGridPreset)
        try container.encodeIfPresent(rhythmMap, forKey: .rhythmMap)
        try container.encodeIfPresent(manualLayoutWidth, forKey: .manualLayoutWidth)
        try container.encode(barlineAfter, forKey: .barlineAfter)
        try container.encode(chordEvents, forKey: .chordEvents)
        try container.encode(cueTextIDs, forKey: .cueTextIDs)
        try container.encode(roadmapObjectIDs, forKey: .roadmapObjectIDs)
        try container.encode(authoringState, forKey: .authoringState)
    }

    func resolvedMeter(defaultMeter: Meter) -> Meter {
        meterOverride ?? defaultMeter
    }

    func resolvedLayoutWidth(defaultWidth: CGFloat) -> CGFloat {
        let proposedWidth = manualLayoutWidth.map { CGFloat($0) } ?? defaultWidth
        return Self.clampedManualLayoutWidth(proposedWidth)
    }

    static func clampedManualLayoutWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumManualLayoutWidth), maximumManualLayoutWidth)
    }
}

enum BeatGridPreset: String, Codable, CaseIterable, Hashable {
    case simple
    case swung
    case eighthSubdivision
    case tripletSubdivision
}

enum BarlineType: String, Codable, CaseIterable, Hashable {
    case single
    case double
    case final
}
