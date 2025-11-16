import XCTest
@testable import TOONCore

final class NumericEdgeCasesTests: XCTestCase {
    
    // MARK: - Integer Boundaries
    
    func testIntMaxValue() throws {
        let toonText = "value: \(Int.max)"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, Double(Int.max))
    }
    
    func testIntMinValue() throws {
        let toonText = "value: \(Int.min)"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, Double(Int.min))
    }
    
    func testInt64MaxValue() throws {
        let toonText = "value: 9223372036854775807"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 9223372036854775807.0)
    }
    
    // MARK: - Zero Variants
    
    func testZero() throws {
        let toonText = "value: 0"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 0.0)
    }
    
    func testZeroDecimal() throws {
        let toonText = "value: 0.0"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 0.0)
    }
    
    func testNegativeZero() throws {
        let toonText = "value: -0"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        // Negative zero should normalize to zero
        XCTAssertEqual(num, 0.0)
    }
    
    func testNegativeZeroDecimal() throws {
        let toonText = "value: -0.0"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 0.0)
    }
    
    func testZeroScientificNotation() throws {
        let toonText = "value: 0e0"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 0.0)
    }
    
    // MARK: - Scientific Notation Boundaries
    
    func testScientificNotationLarge() throws {
        let toonText = "value: 1e308"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 1e308)
        XCTAssertFalse(num.isInfinite)
    }
    
    func testScientificNotationSmall() throws {
        let toonText = "value: 1e-308"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 1e-308)
        XCTAssertFalse(num.isZero)
    }
    
    func testScientificNotationOverflow() throws {
        let toonText = "value: 1e309"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        // Should overflow to infinity
        XCTAssertTrue(num.isInfinite)
    }
    
    func testScientificNotationUnderflow() throws {
        let toonText = "value: 1e-400"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        // Should underflow to zero
        XCTAssertEqual(num, 0.0)
    }
    
    // MARK: - Decimal Precision
    
    func testHighPrecisionDecimal() throws {
        let toonText = "value: 0.123456789012345"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 0.123456789012345, accuracy: 1e-15)
    }
    
    func testRepeatingDecimal() throws {
        let toonText = "value: 0.3333333333333333"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 1.0/3.0, accuracy: 1e-15)
    }
    
    // MARK: - Edge Values
    
    func testVeryLargeInteger() throws {
        let toonText = "value: 999999999999999999"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 999999999999999999.0)
    }
    
    func testVerySmallDecimal() throws {
        let toonText = "value: 0.000000000000001"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 1e-15, accuracy: 1e-20)
    }
    
    func testOne() throws {
        let toonText = "value: 1"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, 1.0)
    }
    
    func testNegativeOne() throws {
        let toonText = "value: -1"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .number(let num) = obj.value(forKey: "value") else {
            XCTFail("Expected object with number value")
            return
        }
        
        XCTAssertEqual(num, -1.0)
    }
    
    // MARK: - Multiple Numbers
    
    func testMultipleZeroVariants() throws {
        let toonText = """
        a: 0
        b: 0.0
        c: -0
        d: -0.0
        e: 0e0
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        // All should be zero
        for key in ["a", "b", "c", "d", "e"] {
            guard case .number(let num) = obj.value(forKey: key) else {
                XCTFail("Expected number for key \(key)")
                continue
            }
            XCTAssertEqual(num, 0.0, "Key \(key) should be zero")
        }
    }
}
