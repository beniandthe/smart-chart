import Foundation
#if canImport(PencilKit)
import PencilKit
#endif

enum ChordInkFixtureExportError: Error, Equatable {
    case emptyInk
    case unsupportedChord(String)
    case encodingFailed
}

enum ChordInkFixtureExporter {
    static func fixtureDocument(
        name: String? = nil,
        expectedDisplayText: String,
        strokes: [InkStroke]
    ) throws -> InkFixtureDocument {
        guard !strokes.isEmpty else {
            throw ChordInkFixtureExportError.emptyInk
        }

        guard let match = ChordRecognitionCompendium.match(expectedDisplayText) else {
            throw ChordInkFixtureExportError.unsupportedChord(expectedDisplayText)
        }

        let displayText = match.displayText
        let expectedTopGlyphs = glyphs(for: displayText)

        return InkFixtureDocument(
            name: name ?? fixtureName(for: displayText),
            expectedDisplayText: displayText,
            expectedClusterCount: expectedTopGlyphs.count,
            expectedTopGlyphs: expectedTopGlyphs,
            strokes: strokes
        )
    }

    static func fixtureJSONString(
        name: String? = nil,
        expectedDisplayText: String,
        strokes: [InkStroke]
    ) throws -> String {
        let document = try fixtureDocument(
            name: name,
            expectedDisplayText: expectedDisplayText,
            strokes: strokes
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)

        guard let string = String(data: data, encoding: .utf8) else {
            throw ChordInkFixtureExportError.encodingFailed
        }

        return string
    }

    #if canImport(PencilKit)
    static func fixtureJSONString(
        name: String? = nil,
        expectedDisplayText: String,
        drawingData: Data
    ) throws -> String {
        try fixtureJSONString(
            name: name,
            expectedDisplayText: expectedDisplayText,
            strokes: PencilKitInkAdapter.inkStrokes(from: drawingData)
        )
    }
    #endif

    static func fixtureName(for displayText: String) -> String {
        let expanded = displayText
            .replacingOccurrences(of: "#", with: "Sharp")
            .replacingOccurrences(of: "♯", with: "Sharp")
            .replacingOccurrences(of: "b", with: "Flat")
            .replacingOccurrences(of: "♭", with: "Flat")
            .replacingOccurrences(of: "-", with: "Minor")
            .replacingOccurrences(of: "/", with: "Slash")
            .replacingOccurrences(of: "△", with: "Major")
            .replacingOccurrences(of: "Δ", with: "Major")
            .replacingOccurrences(of: "∆", with: "Major")

        let sanitized = expanded.filter { character in
            character.isLetter || character.isNumber
        }

        return sanitized.isEmpty ? "ChordInkFixture" : sanitized
    }

    static func glyphs(for displayText: String) -> [String] {
        displayText.map { character in
            if character == "Δ" || character == "∆" {
                return "△"
            }

            return String(character)
        }
    }
}
