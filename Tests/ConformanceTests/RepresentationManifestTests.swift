import XCTest

final class RepresentationManifestTests: XCTestCase {
    func testManifestContainsExpectedFixtures() throws {
        let manifestURL = try XCTUnwrap(Bundle.module.url(
            forResource: "representation-manifest",
            withExtension: "json",
            subdirectory: "Fixtures/encode"
        ))
        let data = try Data(contentsOf: manifestURL)

        guard let manifest = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            XCTFail("Manifest must be a dictionary")
            return
        }

        let expectedFiles: [String] = ["arrays-nested.json", "arrays-tabular.json", "delimiters.json"]
        for file in expectedFiles {
            guard let entries = manifest[file] as? [[String: Any]] else {
                XCTFail("Manifest missing entry for \(file)")
                continue
            }
            XCTAssertFalse(entries.isEmpty, "Manifest entry for \(file) must not be empty")
            for entry in entries {
                XCTAssertNotNil(entry["arrays"], "Entry should describe array representations")
            }
        }
    }
}
