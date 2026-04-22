import Foundation

struct MeasureTimingIssue: Identifiable, Hashable {
    enum Kind: Hashable {
        case invalidStartPosition
        case eventExceedsMeasure
        case overlappingEvents
    }

    var id = UUID()
    var kind: Kind
    var measureID: UUID
    var chordEventID: UUID
    var message: String
}

enum MeasureTimingValidator {
    static func issues(in measure: Measure, defaultMeter: Meter) -> [MeasureTimingIssue] {
        let meter = measure.resolvedMeter(defaultMeter: defaultMeter)
        let measureCapacity = meter.measureLengthInWholeNotes
        let sortedEvents = measure.chordEvents.sorted {
            offset(for: $0, meter: meter) < offset(for: $1, meter: meter)
        }

        var issues: [MeasureTimingIssue] = []
        var previousEventEnd: Double?

        for event in sortedEvents {
            guard let startOffset = event.startPosition.startOffset(in: meter) else {
                issues.append(
                    MeasureTimingIssue(
                        kind: .invalidStartPosition,
                        measureID: measure.id,
                        chordEventID: event.id,
                        message: "Chord \(event.symbol.displayText) has an invalid beat position for \(meter.displayText)."
                    )
                )
                continue
            }

            let eventEnd = startOffset + event.duration.wholeNoteLength

            if eventEnd > measureCapacity + 0.0001 {
                issues.append(
                    MeasureTimingIssue(
                        kind: .eventExceedsMeasure,
                        measureID: measure.id,
                        chordEventID: event.id,
                        message: "Chord \(event.symbol.displayText) runs past the end of the measure."
                    )
                )
            }

            if let previousEventEnd,
               startOffset < previousEventEnd - 0.0001 {
                issues.append(
                    MeasureTimingIssue(
                        kind: .overlappingEvents,
                        measureID: measure.id,
                        chordEventID: event.id,
                        message: "Chord \(event.symbol.displayText) overlaps a previous chord event."
                    )
                )
            }

            previousEventEnd = max(previousEventEnd ?? 0, eventEnd)
        }

        return issues
    }

    private static func offset(for event: ChordEvent, meter: Meter) -> Double {
        event.startPosition.startOffset(in: meter) ?? .greatestFiniteMagnitude
    }
}
