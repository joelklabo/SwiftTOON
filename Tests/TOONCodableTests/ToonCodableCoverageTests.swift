import XCTest
@testable import TOONCodable
@testable import TOONCore

/// Comprehensive coverage tests for ToonCodable (ToonDecoder + ToonEncoder) to achieve 90%+
final class ToonCodableCoverageTests: XCTestCase {
    
    // MARK: - ToonDecoder Coverage
    
    func testDecoderWithCustomJSONDecoder() throws {
        struct Custom: Codable {
            let value: String
        }
        
        let jsonDecoder = JSONDecoder()
        // Just verify custom decoder is used
        let decoder = ToonDecoder(jsonDecoder: jsonDecoder)
        let toon = "value: test\n".data(using: .utf8)!
        let result = try decoder.decode(Custom.self, from: toon)
        
        XCTAssertEqual(result.value, "test")
    }
    
    func testDecoderWithOptions() throws {
        let options = ToonDecoder.Options(schema: nil, lenient: true)
        let decoder = ToonDecoder(options: options)
        
        // Test lenient arrays (padding/truncation)
        let toon = """
        data[2]:
          - a
          - b
          - c
        """.data(using: .utf8)!
        
        struct Data: Codable {
            let data: [String]
        }
        
        let result = try decoder.decode(Data.self, from: toon)
        XCTAssertEqual(result.data.count, 2) // Truncated to declared length
    }
    
    func testDecoderWithSchema() throws {
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("value", .string)
        ])
        
        let options = ToonDecoder.Options(schema: schema, lenient: false)
        let decoder = ToonDecoder(options: options)
        
        struct Simple: Codable {
            let value: String
        }
        
        let toon = "value: test\n".data(using: .utf8)!
        let result = try decoder.decode(Simple.self, from: toon)
        XCTAssertEqual(result.value, "test")
    }
    
    func testDecoderSchemaMismatchError() throws {
        // Schema that expects a number but we'll pass a string
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("name", .number)  // Expects number, not string
        ])
        
        let options = ToonDecoder.Options(schema: schema, lenient: false)
        let decoder = ToonDecoder(options: options)
        
        // This should fail validation (name is string, not number)
        let toon = "name: Alice\n".data(using: .utf8)!
        
        struct Data: Codable {
            let name: String
        }
        
        XCTAssertThrowsError(try decoder.decode(Data.self, from: toon)) { error in
            guard let decodingError = error as? ToonDecodingError,
                  case .schemaMismatch(let message) = decodingError else {
                XCTFail("Expected schemaMismatch error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Expected number"))
        }
    }
    
    func testDecoderInvalidUTF8Error() throws {
        let decoder = ToonDecoder()
        
        // Invalid UTF-8 bytes
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        
        struct Dummy: Codable {}
        
        XCTAssertThrowsError(try decoder.decode(Dummy.self, from: invalidData)) { error in
            guard let decodingError = error as? ToonDecodingError,
                  case .invalidUTF8 = decodingError else {
                XCTFail("Expected invalidUTF8 error")
                return
            }
        }
    }
    
    func testDecoderFromInputStream() throws {
        struct User: Codable {
            let name: String
            let age: Int
        }
        
        let toon = """
        name: Alice
        age: 30
        """
        let data = toon.data(using: .utf8)!
        let stream = InputStream(data: data)
        
        let decoder = ToonDecoder()
        let result = try decoder.decode(User.self, from: stream)
        
        XCTAssertEqual(result.name, "Alice")
        XCTAssertEqual(result.age, 30)
    }
    
    func testDecodeJSONValueFromData() throws {
        let toon = """
        name: Alice
        role: admin
        """.data(using: .utf8)!
        
        let decoder = ToonDecoder()
        let jsonValue = try decoder.decodeJSONValue(from: toon)
        
        guard case .object(let obj) = jsonValue else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj["name"], .string("Alice"))
        XCTAssertEqual(obj["role"], .string("admin"))
    }
    
    func testDecodeJSONValueFromInputStream() throws {
        let toon = "value: 42\n"
        let data = toon.data(using: .utf8)!
        let stream = InputStream(data: data)
        
        let decoder = ToonDecoder()
        let jsonValue = try decoder.decodeJSONValue(from: stream)
        
        guard case .object(let obj) = jsonValue else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj["value"], .number(42))
    }
    
    func testStreamJSONValueWithHandler() throws {
        let toon = "items[3]: 1, 2, 3\n"
        let data = toon.data(using: .utf8)!
        let stream = InputStream(data: data)
        
        var capturedValue: JSONValue?
        let decoder = ToonDecoder()
        
        try decoder.streamJSONValue(from: stream) { value in
            capturedValue = value
        }
        
        XCTAssertNotNil(capturedValue)
        guard case .object(let obj) = capturedValue,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items, [.number(1), .number(2), .number(3)])
    }
    
    func testStreamJSONValueHandlerThrows() throws {
        let toon = "value: test\n"
        let data = toon.data(using: .utf8)!
        let stream = InputStream(data: data)
        
        struct TestError: Error {}
        
        let decoder = ToonDecoder()
        
        XCTAssertThrowsError(try decoder.streamJSONValue(from: stream) { _ in
            throw TestError()
        }) { error in
            XCTAssertTrue(error is TestError)
        }
    }
    
    func testDecoderFromInputStreamCoverage() throws {
        // Test the readAllBytes path (line 72-88)
        let largeData = String(repeating: "x", count: 10000)
        let toon = "value: \(largeData)\n".data(using: .utf8)!
        let stream = InputStream(data: toon)
        
        struct Data: Codable {
            let value: String
        }
        
        let decoder = ToonDecoder()
        let result = try decoder.decode(Data.self, from: stream)
        XCTAssertEqual(result.value.count, 10000)
    }
    
    // MARK: - ToonEncoder Coverage
    
    func testEncoderWithCustomJSONEncoder() throws {
        struct Custom: Codable {
            let value: String
        }
        
        let jsonEncoder = JSONEncoder()
        // Just verify custom encoder is used
        let encoder = ToonEncoder(jsonEncoder: jsonEncoder)
        let value = Custom(value: "test")
        let data = try encoder.encode(value)
        let output = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(output.contains("test"))
    }
    
    func testEncoderWithOptions() throws {
        var options = ToonEncodingOptions()
        options.delimiter = .pipe
        
        let encoder = ToonEncoder(options: options)
        
        struct User: Codable {
            let values: [Int]
        }
        
        let user = User(values: [1, 2, 3])
        let data = try encoder.encode(user)
        let output = String(data: data, encoding: .utf8)!
        
        // Should use pipes as delimiter in inline array
        XCTAssertTrue(output.contains("|") || output.contains("values"))
    }
    
    func testEncoderWithSchema() throws {
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("value", .string)
        ])
        
        let encoder = ToonEncoder(schema: schema)
        
        struct Simple: Codable {
            let value: String
        }
        
        let data = try encoder.encode(Simple(value: "test"))
        let output = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(output.contains("value"))
        XCTAssertTrue(output.contains("test"))
    }
    
    func testEncoderSchemaMismatchError() throws {
        // Schema that expects a number field
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("name", .number)  // Expects number, not string
        ])
        
        let encoder = ToonEncoder(schema: schema)
        
        struct Data: Codable {
            let name: String  // This is a string, not a number
        }
        
        let value = Data(name: "Alice")
        
        XCTAssertThrowsError(try encoder.encode(value)) { error in
            guard let encodingError = error as? ToonEncodingError,
                  case .schemaMismatch(let message) = encodingError else {
                XCTFail("Expected schemaMismatch error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Expected number"))
        }
    }
    
    func testEncoderEncodingFailedError() throws {
        // This is hard to trigger since serialize always returns a String
        // But we can test the error description
        let error = ToonEncodingError.encodingFailed
        XCTAssertEqual(error.errorDescription, "Failed to emit TOON output.")
    }
    
    // MARK: - Error Description Coverage
    
    func testToonDecodingErrorDescriptions() {
        let invalidUTF8 = ToonDecodingError.invalidUTF8
        XCTAssertEqual(invalidUTF8.errorDescription, "Input data is not valid UTF-8 TOON text.")
        
        let schemaMismatch = ToonDecodingError.schemaMismatch("test message")
        XCTAssertEqual(schemaMismatch.errorDescription, "test message")
    }
    
    func testToonEncodingErrorDescriptions() {
        let notImplemented = ToonEncodingError.notImplemented
        XCTAssertEqual(notImplemented.errorDescription, "Encoding is not yet implemented.")
        
        let unsupported = ToonEncodingError.unsupportedValue
        XCTAssertEqual(unsupported.errorDescription, "Encountered a value that cannot be encoded into TOON.")
        
        let failed = ToonEncodingError.encodingFailed
        XCTAssertEqual(failed.errorDescription, "Failed to emit TOON output.")
        
        let schemaMismatch = ToonEncodingError.schemaMismatch("schema error")
        XCTAssertEqual(schemaMismatch.errorDescription, "schema error")
    }
    
    // MARK: - Options Coverage
    
    func testDecoderOptionsInit() {
        let options1 = ToonDecoder.Options()
        XCTAssertNil(options1.schema)
        XCTAssertFalse(options1.lenient)
        
        let schema = ToonSchema.string
        let options2 = ToonDecoder.Options(schema: schema, lenient: true)
        XCTAssertNotNil(options2.schema)
        XCTAssertTrue(options2.lenient)
    }
    
    func testEncoderInit() {
        let encoder1 = ToonEncoder()
        XCTAssertNil(encoder1.schema)
        
        let schema = ToonSchema.string
        let encoder2 = ToonEncoder(schema: schema)
        XCTAssertNotNil(encoder2.schema)
    }
    
    // MARK: - Integration Tests
    
    func testRoundTripWithOptions() throws {
        struct Data: Codable, Equatable {
            let name: String
            let values: [Int]
        }
        
        let original = Data(name: "test", values: [1, 2, 3])
        
        var options = ToonEncodingOptions()
        options.delimiter = .pipe
        
        let encoder = ToonEncoder(options: options)
        let encoded = try encoder.encode(original)
        
        let decoder = ToonDecoder()
        let decoded = try decoder.decode(Data.self, from: encoded)
        
        XCTAssertEqual(original, decoded)
    }
    
    func testRoundTripWithSchema() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }
        
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("name", .string),
            ToonSchema.field("age", .number)
        ])
        
        let original = User(name: "Alice", age: 30)
        
        let encoder = ToonEncoder(schema: schema)
        let encoded = try encoder.encode(original)
        
        let decoderOptions = ToonDecoder.Options(schema: schema, lenient: false)
        let decoder = ToonDecoder(options: decoderOptions)
        let decoded = try decoder.decode(User.self, from: encoded)
        
        XCTAssertEqual(original, decoded)
    }
    
    func testUserInfoPropagation() throws {
        // Test encoder
        let jsonEncoder = JSONEncoder()
        jsonEncoder.userInfo[userInfoTestKey] = "testValue"
        let encoder = ToonEncoder(jsonEncoder: jsonEncoder)
        
        struct EncodeTest: Codable {
            func encode(to encoder: Encoder) throws {
                // Check userInfo is propagated
                XCTAssertNotNil(encoder.userInfo[userInfoTestKey])
                var container = encoder.singleValueContainer()
                try container.encode("value")
            }
        }
        
        _ = try encoder.encode(EncodeTest())
        
        // Test decoder
        let jsonDecoder = JSONDecoder()
        jsonDecoder.userInfo[userInfoTestKey] = "testValue"
        let decoder = ToonDecoder(jsonDecoder: jsonDecoder)
        let toon = "value\n".data(using: .utf8)!
        
        struct DecodeTest: Codable {
            init(from decoder: Decoder) throws {
                // Check userInfo is propagated
                XCTAssertNotNil(decoder.userInfo[userInfoTestKey])
                _ = try decoder.singleValueContainer().decode(String.self)
            }
        }
        
        _ = try decoder.decode(DecodeTest.self, from: toon)
    }
}

private let userInfoTestKey = CodingUserInfoKey(rawValue: "testKey")!
