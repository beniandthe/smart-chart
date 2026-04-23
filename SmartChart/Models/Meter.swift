import Foundation

struct Meter: Codable, Hashable {
    var numerator: Int
    var denominator: Int

    var displayText: String {
        "\(numerator)/\(denominator)"
    }

    var beatUnitWholeNoteLength: Double {
        1 / Double(denominator)
    }

    var measureLengthInWholeNotes: Double {
        Double(numerator) / Double(denominator)
    }
}

struct BeatPosition: Codable, Hashable {
    var beat: Int
    var subdivision: Int
    var subdivisionsPerBeat: Int

    var displayText: String {
        guard subdivision > 0 else { return "\(beat)" }

        let markers = ["", "&", "a", "e", "+"]
        let safeMarker = subdivision < markers.count ? markers[subdivision] : ".\(subdivision)"
        return "\(beat)\(safeMarker)"
    }

    func startOffset(in meter: Meter) -> Double? {
        guard beat >= 1,
              beat <= meter.numerator,
              subdivision >= 0,
              subdivisionsPerBeat > 0,
              subdivision < subdivisionsPerBeat else {
            return nil
        }

        let beatLength = meter.measureLengthInWholeNotes / Double(meter.numerator)
        let subdivisionOffset = Double(subdivision) / Double(subdivisionsPerBeat)
        return (Double(beat - 1) + subdivisionOffset) * beatLength
    }
}

extension BeatPosition {
    init?(offsetInWholeNotes offset: Double, meter: Meter) {
        let beatLength = meter.measureLengthInWholeNotes / Double(meter.numerator)
        guard beatLength > 0 else {
            return nil
        }

        let beatOffset = offset / beatLength
        let wholeBeats = Int(floor(beatOffset + 0.0001))
        let remainder = beatOffset - Double(wholeBeats)

        if abs(remainder) < 0.0001 {
            self.init(beat: wholeBeats + 1, subdivision: 0, subdivisionsPerBeat: 1)
            return
        }

        if abs(remainder - 0.5) < 0.0001 {
            self.init(beat: wholeBeats + 1, subdivision: 1, subdivisionsPerBeat: 2)
            return
        }

        return nil
    }
}

enum RhythmValue: String, Codable, CaseIterable, Hashable {
    case eighth
    case quarter
    case dottedQuarter
    case half
    case dottedHalf
    case whole
    case tiedContinuation

    var displayText: String {
        switch self {
        case .eighth:
            return "eighth"
        case .quarter:
            return "quarter"
        case .dottedQuarter:
            return "dotted quarter"
        case .half:
            return "half"
        case .dottedHalf:
            return "dotted half"
        case .whole:
            return "whole"
        case .tiedContinuation:
            return "tie"
        }
    }

    var wholeNoteLength: Double {
        switch self {
        case .eighth:
            return 0.125
        case .quarter:
            return 0.25
        case .dottedQuarter:
            return 0.375
        case .half:
            return 0.5
        case .dottedHalf:
            return 0.75
        case .whole:
            return 1.0
        case .tiedContinuation:
            return 0.0
        }
    }
}

enum RhythmPlacement: String, Codable, CaseIterable, Hashable {
    case aboveChord
    case belowChord
    case inline
    case hidden
}

enum HitStyle: String, Codable, CaseIterable, Hashable {
    case none
    case accent
    case stab
    case slash
}
