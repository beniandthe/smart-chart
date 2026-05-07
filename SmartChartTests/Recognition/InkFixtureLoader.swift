import Foundation
@testable import SmartChart

typealias InkFixture = InkFixtureDocument

enum InkFixtureLoader {
    static func load(_ name: String, file: StaticString = #filePath) throws -> InkFixture {
        let fixtureURL = fixturesDirectoryURL(relativeTo: file)
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(InkFixture.self, from: data)
    }

    static func loadAll(file: StaticString = #filePath) throws -> [InkFixture] {
        try fixtureURLs(relativeTo: file).map { fixtureURL in
            let data = try Data(contentsOf: fixtureURL)
            return try JSONDecoder().decode(InkFixture.self, from: data)
        }
    }

    static func fixtureNames(file: StaticString = #filePath) throws -> [String] {
        try fixtureURLs(relativeTo: file).map { fixtureURL in
            fixtureURL.deletingPathExtension().lastPathComponent
        }
    }

    private static func fixtureURLs(relativeTo file: StaticString) throws -> [URL] {
        let directoryURL = fixturesDirectoryURL(relativeTo: file)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }

    private static func fixturesDirectoryURL(relativeTo file: StaticString) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("Ink")
    }
}
