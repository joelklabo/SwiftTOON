import Foundation
import XCTest

final class ConformanceTests: XCTestCase {
    struct Manifest: Decodable {
        struct File: Decodable {
            let relativePath: String
            let sha256: String
            let bytes: Int
        }

        let specVersion: String
        let generatedAt: String
        let files: [File]
    }

    func testFixtureManifestExistsAndHasEntries() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertFalse(manifest.specVersion.isEmpty)
        XCTAssertGreaterThan(manifest.files.count, 0, "Run Scripts/update-fixtures.swift if this fails")
    }
}
