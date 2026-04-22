import Foundation

extension Chart {
    mutating func setDocumentFont(_ preset: ChartFontPreset) {
        documentFont = preset
        updatedAt = .now
    }

    mutating func setDocumentKey(_ key: DocumentKey) {
        documentKey = key
        updatedAt = .now
    }

    mutating func setTranspositionView(_ view: TranspositionView) {
        defaultTranspositionView = view
        updatedAt = .now
    }

    mutating func appendMeasure() {
        let nextIndex = measures.count + 1
        let newMeasure = Measure(
            id: UUID(),
            index: nextIndex,
            meterOverride: nil,
            beatGridPreset: .simple,
            barlineAfter: .single,
            chordEvents: [],
            cueTextIDs: [],
            roadmapObjectIDs: []
        )

        guard !systems.isEmpty else {
            systems = [
                ChartSystem(
                    id: UUID(),
                    index: 0,
                    spacingMode: .automatic,
                    lineBreakRule: .automatic,
                    measures: [newMeasure]
                )
            ]
            updatedAt = .now
            return
        }

        let lastIndex = systems.index(before: systems.endIndex)

        if systems[lastIndex].measures.count >= 4 {
            let newSystem = ChartSystem(
                id: UUID(),
                index: systems.count,
                spacingMode: .automatic,
                lineBreakRule: .automatic,
                measures: [newMeasure]
            )
            systems.append(newSystem)
        } else {
            systems[lastIndex].measures.append(newMeasure)
        }

        updatedAt = .now
    }

    mutating func addSectionLabel(text: String, type: SectionLabelType = .sectionName) {
        guard let firstSystem = systems.first,
              let firstMeasure = firstSystem.measures.first else {
            return
        }

        sectionLabels.append(
            SectionLabel(
                id: UUID(),
                text: text,
                type: type,
                anchorMeasureID: firstMeasure.id,
                anchorSystemID: firstSystem.id,
                rawInput: text
            )
        )

        updatedAt = .now
    }

    mutating func addCueText(_ text: String) {
        guard !systems.isEmpty, !systems[0].measures.isEmpty else {
            return
        }

        let firstMeasure = systems[0].measures[0]
        let cue = CueText(
            id: UUID(),
            text: text,
            anchorMeasureID: firstMeasure.id,
            position: .below,
            emphasis: .normal,
            rawInput: text
        )

        cueTexts.append(
            cue
        )
        systems[0].measures[0].cueTextIDs.append(cue.id)

        updatedAt = .now
    }

    mutating func addRoadmapObject(_ type: RoadmapType, displayText: String? = nil) {
        guard !systems.isEmpty, !systems[0].measures.isEmpty else {
            return
        }

        let roadmap = RoadmapObject(
            id: UUID(),
            type: type,
            startMeasureID: systems[0].measures[0].id,
            endMeasureID: nil,
            anchorSystemID: systems[0].id,
            placement: .floatingTop,
            displayText: displayText,
            count: nil,
            linkedTargetID: nil,
            rawInput: displayText ?? type.defaultDisplayText
        )
        roadmapObjects.append(roadmap)
        systems[0].measures[0].roadmapObjectIDs.append(roadmap.id)

        updatedAt = .now
    }
}

extension Measure {
    mutating func addDemoChordEvent() {
        let demoEvent = ChordEvent(
            id: UUID(),
            symbol: ChordSymbol(
                root: .c,
                accidental: .natural,
                quality: "7",
                extensions: [],
                alterations: [],
                slashBass: nil
            ),
            startPosition: BeatPosition(beat: 1, subdivision: 0, subdivisionsPerBeat: 2),
            duration: .quarter,
            rhythmPlacement: .belowChord,
            tieOut: false,
            hitStyle: .accent,
            rawInput: "C7"
        )

        chordEvents.append(demoEvent)
    }
}
