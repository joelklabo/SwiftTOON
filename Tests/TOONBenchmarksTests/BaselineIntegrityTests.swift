import XCTest

final class BaselineIntegrityTests: XCTestCase {
    func testBaselineFileIsValidJSON() throws {
        let url = URL(fileURLWithPath: "Benchmarks/baseline_reference.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Baseline file must exist")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssert(object is [Any], "Baseline JSON must decode to an array of samples")
    }
}
