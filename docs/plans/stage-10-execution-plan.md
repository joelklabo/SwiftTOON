# Stage 10: Coverage Excellence - Detailed Execution Plan

**Goal:** 92.73% → 95%+ line coverage (stretch: 99%)  
**Current Status:** 92.73% line / 86.67% regions (588 tests expected)  
**Remaining Gap:** ~80 uncovered lines across 4 priority modules

---

## Quick Reference

### Priority Modules (Highest ROI First)
1. **ToonSchema.swift** - 90.53% (9 lines) - ✅ Phase 1 DONE (32 tests pending CI)
2. **JSONTextParser.swift** - 93.15% (15 lines) - 🔄 Phase 2 NEXT
3. **JSONValueDecoder.swift** - 91.30% (16 lines) - 🔄 Phase 3
4. **Parser.swift** - 91.64% (56 lines) - 🔄 Phase 4

### Expected Impact
- Phase 2: +0.5% overall (93.15% → 97%+ JSONTextParser)
- Phase 3: +0.5% overall (91.30% → 96%+ JSONValueDecoder)
- Phase 4: +1.7% overall (91.64% → 94%+ Parser)
- **Total: +2.7% → 95.4% overall**

---

## Phase 1: ToonSchema ✅ COMPLETE

**Status:** 32 tests created, awaiting CI validation  
**File:** `Tests/TOONCodableTests/ToonSchemaComprehensiveTests.swift`

**Coverage Added:**
- .any schema validation (6 tests)
- .null schema validation (3 tests)
- Type mismatch error paths (6 tests)
- Nested schema validation (4 tests)
- Helper method coverage (7 tests)
- Error descriptions (3 tests)
- Complex mixed scenarios (3 tests)

**Lines Covered:**
- Line 55: .any case
- Line 63: .null case
- Lines 66, 85: type mismatch throws
- Line 110: allowsAdditionalKeys
- Lines 125, 127, 133, 135: typeDescription cases

---

## Phase 2: JSONTextParser Edge Cases 🔄 NEXT

**Target:** 93.15% → 97%+ lines  
**Gap:** 15 uncovered lines  
**Effort:** 10-15 tests, ~30-45 minutes  
**File to create:** `Tests/TOONCoreTests/JSONTextParserComprehensiveTests.swift`

### Uncovered Lines Analysis

Run this to see exact lines:
```bash
PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
xcrun llvm-cov show .build/arm64-apple-macosx/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
  -instr-profile="$PROFILE" \
  Sources/TOONCore/JSONTextParser.swift \
  -format=text | grep -E "^\s+[0-9]+\|.*0\|"
```

### Tests to Write

#### Test Group 1: Unicode Escape Sequences (4 tests)
```swift
func testBasicUnicodeEscape() throws {
    // \u0041 = "A"
    let json = #""\\u0041""#
    let result = try JSONTextParser.parse(json)
    XCTAssertEqual(result, .string("A"))
}

func testSurrogatePairEscape() throws {
    // High + low surrogate for emoji
    let json = #""\\uD83D\\uDE00""#  // 😀
    let result = try JSONTextParser.parse(json)
    XCTAssertEqual(result, .string("😀"))
}

func testInvalidUnicodeEscape() {
    // Invalid hex digits
    let json = #""\\uZZZZ""#
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}

func testTruncatedUnicodeEscape() {
    // Only 3 hex digits
    let json = #""\\u004""#
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}
```

#### Test Group 2: All Escape Characters (3 tests)
```swift
func testAllBasicEscapes() throws {
    let json = #""\\t\\r\\n\\"\\\\\\\/""#
    let result = try JSONTextParser.parse(json)
    XCTAssertEqual(result, .string("\t\r\n\"\\/"))
}

func testEscapeAtStringBoundaries() throws {
    // Escape at start and end
    let json = #""\\ttext\\n""#
    let result = try JSONTextParser.parse(json)
    XCTAssertEqual(result, .string("\ttext\n"))
}

func testInvalidEscapeSequence() {
    // \x is not valid
    let json = #""\\x41""#
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}
```

#### Test Group 3: Scientific Notation (4 tests)
```swift
func testScientificNotationPositiveExponent() throws {
    let json = "1.23e10"
    let result = try JSONTextParser.parse(json)
    guard case .number(let n) = result else {
        return XCTFail("Expected number")
    }
    XCTAssertEqual(n, 1.23e10)
}

func testScientificNotationNegativeExponent() throws {
    let json = "1.5e-308"
    let result = try JSONTextParser.parse(json)
    guard case .number(let n) = result else {
        return XCTFail("Expected number")
    }
    XCTAssertEqual(n, 1.5e-308)
}

func testScientificNotationOverflow() throws {
    // Should handle gracefully (infinity or error)
    let json = "1e309"
    let result = try JSONTextParser.parse(json)
    guard case .number(let n) = result else {
        return XCTFail("Expected number")
    }
    XCTAssertTrue(n.isInfinite)
}

func testScientificNotationCapitalE() throws {
    let json = "2.5E3"
    let result = try JSONTextParser.parse(json)
    guard case .number(let n) = result else {
        return XCTFail("Expected number")
    }
    XCTAssertEqual(n, 2500.0)
}
```

#### Test Group 4: Numeric Edge Cases (3 tests)
```swift
func testLeadingZeros() {
    // Leading zeros are invalid in JSON
    let json = "007"
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}

func testNegativeZero() throws {
    let json = "-0"
    let result = try JSONTextParser.parse(json)
    guard case .number(let n) = result else {
        return XCTFail("Expected number")
    }
    XCTAssertEqual(n, -0.0)
}

func testTrailingDecimalPoint() {
    // 1. is invalid (must have digits after decimal)
    let json = "1."
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}
```

#### Test Group 5: Malformed JSON Error Recovery (2 tests)
```swift
func testUnterminatedString() {
    let json = #""unterminated"#
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}

func testUnexpectedToken() {
    let json = "]["
    XCTAssertThrowsError(try JSONTextParser.parse(json))
}
```

### Execution Steps

1. **Generate coverage report:**
   ```bash
   swift test --enable-code-coverage --parallel
   PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
   xcrun llvm-cov show ... Sources/TOONCore/JSONTextParser.swift > /tmp/jsontext-coverage.txt
   ```

2. **Create test file:**
   - Copy template above
   - Adjust based on actual uncovered lines from coverage report
   - Add 2-3 more tests if needed for complete coverage

3. **Run tests:**
   ```bash
   swift test --filter JSONTextParserComprehensiveTests
   ```

4. **Verify coverage increase:**
   ```bash
   swift test --enable-code-coverage --parallel
   PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
   swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts
   cat coverage-artifacts/coverage-summary.json | jq '.lines.percent'
   ```

5. **Commit:**
   ```bash
   git add Tests/TOONCoreTests/JSONTextParserComprehensiveTests.swift
   git commit -m "test: add JSONTextParser comprehensive coverage (Phase 2)
   
   Coverage: JSONTextParser 93.15% → 97%+ (+3.85%)
   Overall: ~92.73% → ~93.2% (+0.5%)
   
   Tests added (14):
   - Unicode escape sequences (4)
   - All escape characters (3)
   - Scientific notation (4)
   - Numeric edge cases (3)
   
   Covers: escape handling, unicode, scientific notation, malformed JSON"
   git push
   ```

---

## Phase 3: JSONValueDecoder Refinement 🔄

**Target:** 91.30% → 96%+ lines  
**Gap:** 16 uncovered lines  
**Effort:** 10-15 tests, ~30-45 minutes  
**File to create:** `Tests/TOONCodableTests/JSONValueDecoderEdgeCaseTests.swift`

### Tests to Write

#### Test Group 1: Nested Container Combinations (4 tests)
```swift
func testNestedUnkeyedInKeyed() throws {
    let value: JSONValue = .object([
        "items": .array([.number(1), .number(2)])
    ])
    let decoder = JSONValueDecoder()
    let container = try decoder.container(keyedBy: CodingKeys.self, wrapping: value)
    var nested = try container.nestedUnkeyedContainer(forKey: .items)
    XCTAssertEqual(try nested.decode(Int.self), 1)
    XCTAssertEqual(try nested.decode(Int.self), 2)
}

func testNestedKeyedInUnkeyed() throws {
    let value: JSONValue = .array([
        .object(["key": .string("value")])
    ])
    let decoder = JSONValueDecoder()
    var container = try decoder.unkeyedContainer(wrapping: value)
    let nested = try container.nestedContainer(keyedBy: CodingKeys.self)
    XCTAssertEqual(try nested.decode(String.self, forKey: .key), "value")
}

func testDoubleNesting() throws {
    // keyed -> unkeyed -> keyed
    let value: JSONValue = .object([
        "outer": .array([
            .object(["inner": .number(42)])
        ])
    ])
    struct Test: Decodable {
        let outer: [Inner]
        struct Inner: Decodable {
            let inner: Int
        }
    }
    let result = try JSONValueDecoder().decode(Test.self, from: value)
    XCTAssertEqual(result.outer[0].inner, 42)
}

func testTripleNesting() throws {
    // Test maximum nesting depth
    let value: JSONValue = .array([
        .array([
            .array([.number(1)])
        ])
    ])
    let result = try JSONValueDecoder().decode([[[Int]]].self, from: value)
    XCTAssertEqual(result[0][0][0], 1)
}
```

#### Test Group 2: superDecoder Edge Cases (3 tests)
```swift
func testSuperDecoderWithNonStandardKey() throws {
    let value: JSONValue = .object([
        "super": .object(["nested": .string("value")])
    ])
    // Decode using superDecoder
    struct Wrapper: Decodable {
        let nested: String
        init(from decoder: Decoder) throws {
            let superDecoder = try decoder.container(keyedBy: CodingKeys.self)
                .superDecoder(forKey: .super)
            let container = try superDecoder.container(keyedBy: NestedKeys.self)
            self.nested = try container.decode(String.self, forKey: .nested)
        }
        enum CodingKeys: String, CodingKey { case `super` }
        enum NestedKeys: String, CodingKey { case nested }
    }
    let result = try JSONValueDecoder().decode(Wrapper.self, from: value)
    XCTAssertEqual(result.nested, "value")
}

func testSuperDecoderInUnkeyedContainer() throws {
    let value: JSONValue = .array([
        .object(["key": .string("value")])
    ])
    var container = try JSONValueDecoder().unkeyedContainer(wrapping: value)
    let superDecoder = try container.superDecoder()
    let nested = try superDecoder.container(keyedBy: TestKeys.self)
    XCTAssertEqual(try nested.decode(String.self, forKey: .key), "value")
}

func testSuperDecoderFailsWhenNotObject() {
    let value: JSONValue = .string("not an object")
    let container = try? JSONValueDecoder().container(keyedBy: CodingKeys.self, wrapping: value)
    XCTAssertNil(container)
}
```

#### Test Group 3: Type Mismatch Paths (3 tests)
```swift
func testDecodeIntFromString() {
    let value: JSONValue = .string("not a number")
    XCTAssertThrowsError(try JSONValueDecoder().decode(Int.self, from: value))
}

func testDecodeArrayFromObject() {
    let value: JSONValue = .object(["key": .string("value")])
    XCTAssertThrowsError(try JSONValueDecoder().decode([String].self, from: value))
}

func testDecodeObjectFromArray() {
    let value: JSONValue = .array([.number(1)])
    struct Test: Decodable {
        let key: String
    }
    XCTAssertThrowsError(try JSONValueDecoder().decode(Test.self, from: value))
}
```

#### Test Group 4: Empty Containers (2 tests)
```swift
func testDecodeEmptyArray() throws {
    let value: JSONValue = .array([])
    let result = try JSONValueDecoder().decode([Int].self, from: value)
    XCTAssertTrue(result.isEmpty)
}

func testDecodeEmptyObject() throws {
    let value: JSONValue = .object([:])
    struct Empty: Decodable {}
    let result = try JSONValueDecoder().decode(Empty.self, from: value)
    XCTAssertNotNil(result)
}
```

#### Test Group 5: Container Boundary Conditions (3 tests)
```swift
func testDecodeAllKeys() throws {
    let value: JSONValue = .object([
        "a": .number(1),
        "b": .number(2),
        "c": .number(3)
    ])
    let container = try JSONValueDecoder().container(keyedBy: DynamicKey.self, wrapping: value)
    let keys = container.allKeys.map(\.stringValue).sorted()
    XCTAssertEqual(keys, ["a", "b", "c"])
}

func testUnkeyedContainerCount() throws {
    let value: JSONValue = .array([.number(1), .number(2), .number(3)])
    var container = try JSONValueDecoder().unkeyedContainer(wrapping: value)
    XCTAssertEqual(container.count, 3)
    XCTAssertFalse(container.isAtEnd)
    _ = try container.decode(Int.self)
    _ = try container.decode(Int.self)
    _ = try container.decode(Int.self)
    XCTAssertTrue(container.isAtEnd)
}

func testDecodeNilFromNull() throws {
    let value: JSONValue = .null
    let result = try JSONValueDecoder().decode(Optional<String>.self, from: value)
    XCTAssertNil(result)
}
```

### Execution Steps
Same as Phase 2 (generate coverage, create tests, verify, commit)

---

## Phase 4: Parser Final Polish 🔄

**Target:** 91.64% → 94%+ lines  
**Gap:** 56 uncovered lines (largest)  
**Effort:** 20-25 tests, ~60-90 minutes  
**File to create:** `Tests/TOONCoreTests/ParserEdgeCasesComprehensiveTests.swift`

### Tests to Write

#### Test Group 1: Lenient Mode Branches (5 tests)
```swift
func testLenientPadsShortInlineArray() throws {
    // More detailed lenient mode testing
}

func testLenientTruncatesLongInlineArray() throws {
    // Inline [3]: a,b,c,d,e -> keeps 3
}

func testLenientPadsShortTabularColumn() throws {
    // Tabular row with missing columns
}

func testLenientHandlesJaggedListArray() throws {
    // List array with varying item counts
}

func testStrictModeRejectsLenientCases() {
    // Ensure strict mode fails where lenient succeeds
}
```

#### Test Group 2: EOF Edge Cases (5 tests)
```swift
func testEOFInMiddleOfObject() {
    // key: value
    // [EOF]
}

func testEOFInMiddleOfArray() {
    // items[3]:
    //   - a
    //   - b
    // [EOF]
}

func testEOFAfterColon() {
    // key:
    // [EOF]
}

func testEOFInTabularHeader() {
    // items[2]{a,b
    // [EOF]
}

func testEOFAfterDash() {
    // items[1]:
    //   -
    // [EOF]
}
```

#### Test Group 3: Malformed Tabular Arrays (5 tests)
```swift
func testTabularMissingHeader() {
    // items[2]:
    //   1,2  (no header)
}

func testTabularHeaderCountMismatch() {
    // items[2]{a,b,c}:  (3 headers for length 2)
}

func testTabularRowTooShort() {
    // items[3]{a,b,c}:
    //   1,2  (only 2 values)
}

func testTabularRowTooLong() {
    // items[2]{a,b}:
    //   1,2,3  (3 values)
}

func testTabularInvalidDelimiter() {
    // items[2]{a,b}:
    //   1;2  (semicolon instead of comma)
}
```

#### Test Group 4: Deep Nesting (3 tests)
```swift
func testDeeplyNestedObjects() throws {
    // 10+ levels of nesting
}

func testDeeplyNestedArrays() throws {
    // Arrays within arrays 5+ levels
}

func testMixedDeepNesting() throws {
    // Objects and arrays interleaved deeply
}
```

#### Test Group 5: Whitespace/Indent Edge Cases (5 tests)
```swift
func testTabsInIndentation() {
    // Tabs should be rejected
}

func testMixedTabsAndSpaces() {
    // Mixed should be rejected
}

func testInconsistentIndentWidth() {
    // 2 spaces then 4 spaces
}

func testIndentWithoutKey() {
    //   value  (indent but no key)
}

func testTrailingWhitespaceInValue() throws {
    // key: value   
    // Should trim or preserve?
}
```

#### Test Group 6: Remaining Error Paths (3 tests)
```swift
func testUnexpectedTokenAfterValue() {
    // value1 value2  (no delimiter)
}

func testInvalidArrayLength() {
    // items[abc]:  (non-numeric length)
}

func testNegativeArrayLength() {
    // items[-5]:
}
```

### Execution Steps
Same as Phase 2 & 3

---

## Success Criteria

### Coverage Targets
- [ ] JSONTextParser: 97%+ lines
- [ ] JSONValueDecoder: 96%+ lines
- [ ] Parser: 94%+ lines
- [ ] Overall: 95%+ lines
- [ ] Overall: 90%+ regions

### Quality Gates
- [ ] All new tests pass
- [ ] Zero regressions in existing tests
- [ ] No performance degradation (run benchmarks)
- [ ] Clean commit messages with coverage metrics

### Documentation
- [ ] Update `coverage-strategy.md` with results
- [ ] Update `plan.md` Stage 10 status
- [ ] Create session summary for Phase 2-4 work

---

## Workflow for Each Phase

1. **Before starting:**
   ```bash
   git pull
   swift test --enable-code-coverage --parallel  # Get baseline
   ```

2. **Generate coverage report:**
   ```bash
   PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
   xcrun llvm-cov show ... Sources/.../TargetFile.swift -format=text > /tmp/coverage.txt
   grep "0|" /tmp/coverage.txt  # Find uncovered lines
   ```

3. **Write tests** (use templates above)

4. **Run & verify:**
   ```bash
   swift test --filter YourNewTests
   swift test --enable-code-coverage --parallel
   # Check coverage increase
   ```

5. **Commit & push:**
   ```bash
   git add Tests/.../YourNewTestFile.swift
   git commit -m "test: add [module] comprehensive coverage (Phase X)
   
   Coverage: [module] X% → Y% (+Z%)
   Overall: ~A% → ~B% (+C%)
   
   Tests added (N):
   - Test group 1
   - Test group 2
   
   Covers: [what lines/scenarios]"
   git push
   ```

6. **Update plan:**
   - Mark phase complete
   - Update coverage numbers
   - Document any findings

---

## Tips & Tricks

### Quick Coverage Check
```bash
alias cov='swift test --enable-code-coverage --parallel && PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit) && swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts && cat coverage-artifacts/coverage-summary.json | jq ".lines.percent"'
```

### Generate HTML Report for Specific File
```bash
PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
xcrun llvm-cov show .build/arm64-apple-macosx/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
  -instr-profile="$PROFILE" \
  Sources/TOONCore/JSONTextParser.swift \
  -format=html \
  -output-dir=/tmp/coverage-html
open /tmp/coverage-html/index.html
```

### Test Specific Module
```bash
swift test --filter JSONTextParserComprehensiveTests
swift test --filter JSONValueDecoderEdgeCaseTests
swift test --filter ParserEdgeCasesComprehensiveTests
```

### Watch Coverage Changes
```bash
watch -n 30 'swift test --enable-code-coverage --parallel 2>&1 | tail -5 && PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit) && swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts && cat coverage-artifacts/coverage-summary.json | jq ".lines.percent"'
```

---

## Estimated Timeline

| Phase | Tests | Time | Coverage Gain |
|-------|-------|------|---------------|
| Phase 1 | 32 | ✅ Done | +0.3% |
| Phase 2 | 10-15 | 30-45 min | +0.5% |
| Phase 3 | 10-15 | 30-45 min | +0.5% |
| Phase 4 | 20-25 | 60-90 min | +1.7% |
| **Total** | **72-87** | **2-3 hours** | **+3.0%** |

---

## Next Action

**Start Phase 2 now:**
```bash
# 1. Generate coverage for JSONTextParser
PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
xcrun llvm-cov show .build/arm64-apple-macosx/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
  -instr-profile="$PROFILE" \
  Sources/TOONCore/JSONTextParser.swift \
  -format=text | grep -E "^\s+[0-9]+\|" > /tmp/jsontext-coverage.txt

# 2. Create test file
touch Tests/TOONCoreTests/JSONTextParserComprehensiveTests.swift

# 3. Follow Phase 2 test templates above

# 4. Run and commit when done
```

**Ready to execute Phase 2!** 🚀
