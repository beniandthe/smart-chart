import Foundation

struct Measure: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var meterOverride: Meter?
    var beatGridPreset: BeatGridPreset
    var barlineAfter: BarlineType
    var chordEvents: [ChordEvent]
    var cueTextIDs: [UUID]
    var roadmapObjectIDs: [UUID]

    func resolvedMeter(defaultMeter: Meter) -> Meter {
        meterOverride ?? defaultMeter
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
