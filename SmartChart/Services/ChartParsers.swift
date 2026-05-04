import Foundation

enum MeterParseError: Error {
    case invalidFormat
    case invalidValue
}

enum ChordSymbolParseError: Error {
    case invalidRoot
    case invalidSlashBass
    case unsupportedMajorQuality
}

enum MeterParser {
    static func parse(_ text: String) throws -> Meter {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = trimmed.split(separator: "/", maxSplits: 1).map(String.init)

        guard pieces.count == 2,
              let numerator = Int(pieces[0]),
              let denominator = Int(pieces[1]) else {
            throw MeterParseError.invalidFormat
        }

        let validDenominators = [1, 2, 4, 8, 16, 32]
        guard numerator > 0, validDenominators.contains(denominator) else {
            throw MeterParseError.invalidValue
        }

        return Meter(numerator: numerator, denominator: denominator)
    }
}

enum ChordSymbolParser {
    static func parse(_ text: String) throws -> ChordSymbol {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rootPitch = parseLeadingPitch(from: trimmed) else {
            throw ChordSymbolParseError.invalidRoot
        }

        let descriptorStart = descriptorStartIndex(in: trimmed)
        let descriptorText = String(trimmed[descriptorStart...])
        let pieces = descriptorText.split(separator: "/", maxSplits: 1).map(String.init)
        let descriptor = pieces.first ?? ""
        let slashBass = pieces.count > 1 ? pieces[1] : nil

        let parsedSlashBass = slashBass.flatMap(ChordPitch.parse)

        if slashBass != nil,
           parsedSlashBass == nil {
            throw ChordSymbolParseError.invalidSlashBass
        }

        if isUnsupportedMajorDescriptor(descriptor) {
            throw ChordSymbolParseError.unsupportedMajorQuality
        }

        let parsedDescriptor = parseDescriptor(descriptor)

        return ChordSymbol(
            root: rootPitch.root,
            accidental: rootPitch.accidental,
            quality: parsedDescriptor.quality,
            extensions: parsedDescriptor.extensions,
            alterations: parsedDescriptor.alterations,
            slashBass: parsedSlashBass?.displayText
        )
    }

    private static func parseLeadingPitch(from text: String) -> ChordPitch? {
        guard let first = text.first else { return nil }

        let root = String(first)
        if text.count > 1 {
            let nextIndex = text.index(after: text.startIndex)
            let second = text[nextIndex]

            if second == "#" || second == "b" || second == "B" {
                return ChordPitch.parse(root + String(second))
            }
        }

        return ChordPitch.parse(root)
    }

    private static func descriptorStartIndex(in text: String) -> String.Index {
        guard text.count > 1 else { return text.endIndex }

        let secondIndex = text.index(after: text.startIndex)
        let second = text[secondIndex]

        if second == "#" || second == "b" || second == "B" {
            return text.index(after: secondIndex)
        }

        return secondIndex
    }

    private static func parseDescriptor(_ descriptor: String) -> (quality: String, extensions: [String], alterations: [String]) {
        var quality = ""
        var extensions: [String] = []
        var alterations: [String] = []

        let descriptor = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = Array(descriptor)
        var index = 0
        let lowercasedDescriptor = descriptor.lowercased()

        if lowercasedDescriptor.hasPrefix("minor") {
            quality = "-"
            index = 5
        } else if lowercasedDescriptor.hasPrefix("min") {
            quality = "-"
            index = 3
        } else if descriptor.hasPrefix("m") {
            quality = "-"
            index = 1
        } else if lowercasedDescriptor.hasPrefix("-") {
            quality = "-"
            index = 1
        }

        while index < characters.count {
            let character = characters[index]

            if character == "#" || character == "b" {
                var token = String(character)
                index += 1

                while index < characters.count, characters[index].isNumber {
                    token.append(characters[index])
                    index += 1
                }

                alterations.append(token)
            } else if character.isNumber {
                var token = String(character)
                index += 1

                while index < characters.count, characters[index].isNumber {
                    token.append(characters[index])
                    index += 1
                }

                extensions.append(token)
            } else if !character.isWhitespace {
                quality.append(character)
                index += 1
            } else {
                index += 1
            }
        }

        return (quality, extensions, alterations)
    }

    private static func isUnsupportedMajorDescriptor(_ descriptor: String) -> Bool {
        let trimmedDescriptor = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedDescriptor = trimmedDescriptor.lowercased()

        if trimmedDescriptor == "M" {
            return true
        }

        return lowercasedDescriptor.hasPrefix("maj")
            || lowercasedDescriptor.hasPrefix("major")
    }
}
