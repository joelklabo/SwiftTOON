import XCTest
@testable import TOONCore

final class UnquotedStringTests: XCTestCase {
    func testUnquotedEmailAddress() throws {
        // @ symbol should be allowed in unquoted strings per TOON spec §7.2
        let input = "email: user@example.com"
        let document = try TOONDecoder().decode(input)
        
        XCTAssertEqual(document["email"]?.stringValue, "user@example.com")
    }
    
    func testMultipleAtSymbols() throws {
        let input = "path: @@special@@"
        let document = try TOONDecoder().decode(input)
        
        XCTAssertEqual(document["path"]?.stringValue, "@@special@@")
    }
}
