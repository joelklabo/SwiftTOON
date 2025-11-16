# Coverage Excellence Strategy (Stage 10)

**Goal:** Achieve ≥99% line coverage and ≥97% branch coverage across `TOONCore` and `TOONCodable`.

**Current State:** 92.23% line / 93.98% function (538 tests) ✅

**Final Progress Summary:**
- Session Start: 91.29% line coverage (408 tests)
- Final: 92.23% line coverage (538 tests)
- Achievement: +0.94% line, +130 tests (+31.9%!)

**Major Transformations:**
- **Parser:** 83.73% → 91.64% (+7.91%!) 🏆 Biggest win - from bottleneck to good
- **Lexer:** 95.70% → 97.68% (+1.98%) ⭐ Approaching perfection
- **TOONCore:** 88.40% → 92.29% (+3.89%) ✅ Major progress
- **JSONValueDecoder:** 76.63% → ~85%+ (+8%+) ✅ Dramatic lift

**Module Breakdown (final):**
- Lexer: 97.68% line ⭐ (excellent, -2.32% to 100%)
- TOONCodable: 94.52% line ✅ (strong, -4.48% to 99%)
- TOONCore: 92.29% line ✅ (very good, -6.71% to 99%)
- Parser: 91.64% line ✅ (good, transformed from worst)

**Tests Created This Session (9 files, 130 tests):**
1. ParserRemainingCoverageTests (29) - Array edge cases, lenient mode
2. JSONValueDecoderRemainingTests (15) - Nested containers, type conversions
3. ParserUncoveredPathsTests (21) - Delimiters, nesting, whitespace
4. ParserSurgicalCoverageTests (15) - List items, EOF handling
5. **ParserParseValueTriggerTests (10)** ⭐ BREAKTHROUGH - Unusual tokens
6. ParserPerformanceTrackerTests (7) - Performance tracking APIs
7. ParserErrorPathsTests (+6, now 23) - Error path coverage
8. LexerEdgeCaseTests (13) - Line endings, character errors
9. ParserFinalGapsTests (13) - Final coverage push

## Phase 1: Coverage Analysis & Gap Identification ✅

Completed with 97 targeted tests addressing major gaps.

**Remaining Gaps (to reach 95%+):**
- Parser: 53 uncovered lines (error paths: lines 140, 152, 156-159, 174, 182-186, 199, 327, 359-363)
- JSONTextParser: 15 missed lines (93.15% - JSON parsing edge cases)
- Lexer: 13 missed lines (95.70% - error paths, rare tokens)
- ParserPerformanceTracker: 21 missed lines (69.12% - observability, acceptable)

### Step 1.1: Generate Detailed Coverage Report

```bash
# Run tests with coverage
swift test --enable-code-coverage --parallel

# Find profile
PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)

# Generate badge/summary
swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts

# Generate HTML report for TOONCore
xcrun llvm-cov show .build/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
  -instr-profile="$PROFILE" \
  Sources/TOONCore \
  -format=html \
  -output-dir=coverage-artifacts/TOONCore

# Generate HTML report for TOONCodable  
xcrun llvm-cov show .build/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
  -instr-profile="$PROFILE" \
  Sources/TOONCodable \
  -format=html \
  -output-dir=coverage-artifacts/TOONCodable
```

### Step 1.2: Analyze Uncovered Lines by File

```bash
# Generate line-by-line coverage for each source file
for file in Sources/TOONCore/*.swift; do
  echo "=== $(basename $file) ==="
  xcrun llvm-cov report .build/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
    -instr-profile="$PROFILE" \
    "$file"
done
```

### Step 1.3: Categorize Coverage Gaps

Create `coverage-gaps.md` with structure:

```markdown
## TOONCore

### Lexer.swift (XX% → 99%)
- [ ] Line 123: Error path for invalid UTF-8 sequence
- [ ] Line 145-148: Numeric overflow edge case
- [ ] Lines 200-205: EOF handling in quoted strings

### Parser.swift (XX% → 99%)
- [ ] Lines 350-355: Lenient mode padding for short tabular rows
- [ ] Lines 400-410: Deeply nested object error recovery
- [ ] Line 500: Schema mismatch error formatting

## TOONCodable

### ToonDecoder.swift (XX% → 99%)
- [ ] Lines 100-105: InputStream chunk boundary edge case
- [ ] Line 150: Schema validation failure path
- [ ] Lines 200-210: Optional field decoding with nil values
```

## Phase 2: Systematic Test Addition (Category by Category)

### Category A: Error Path Coverage

**Target:** All `throw` statements, error constructors, validation failures

#### TOONCore Error Paths
```swift
// Tests/TOONCoreTests/ParserErrorPathsTests.swift
final class ParserErrorPathsTests: XCTestCase {
    func testInvalidIndentThrows() {
        // Cover: Parser line XXX - inconsistent indent width
        let toonText = """
        key1: value1
          key2: value2
           key3: value3
        """
        XCTAssertThrowsError(try Parser().parse(toonText))
    }
    
    func testMalformedArrayLengthThrows() {
        // Cover: Parser line YYY - invalid array length syntax
        let toonText = "items[abc]: 1,2,3"
        XCTAssertThrowsError(try Parser().parse(toonText))
    }
    
    func testUnterminatedStringThrows() {
        // Cover: Lexer line ZZZ - EOF in string literal
        let toonText = "key: \"unterminated"
        XCTAssertThrowsError(try Parser().parse(toonText))
    }
}
```

#### TOONCodable Error Paths
```swift
// Tests/TOONCodableTests/DecoderErrorPathsTests.swift
final class DecoderErrorPathsTests: XCTestCase {
    func testSchemaMismatchThrows() {
        // Cover: ToonDecoder line XXX - type mismatch
        let schema = ToonSchema.object(fields: [
            .field("id", .number)
        ], allowAdditionalKeys: false)
        let toonText = "id: not_a_number"
        let decoder = ToonDecoder(options: .init(schema: schema))
        
        XCTAssertThrowsError(try decoder.decode([String: Int].self, from: Data(toonText.utf8)))
    }
    
    func testStreamInterruptionThrows() {
        // Cover: ToonDecoder line YYY - partial stream read
        let brokenStream = BrokenInputStream()
        XCTAssertThrowsError(try decoder.decodeJSONValue(from: brokenStream))
    }
}
```

### Category B: Edge Case Coverage

**Target:** Boundary conditions, empty collections, extreme values

#### Numeric Edge Cases
```swift
// Tests/TOONCoreTests/NumericEdgeCasesTests.swift
final class NumericEdgeCasesTests: XCTestCase {
    func testIntMaxValue() {
        let toonText = "value: \(Int.max)"
        let result = try Parser().parse(toonText)
        // Verify parsing and round-trip
    }
    
    func testScientificNotationBoundaries() {
        let cases = [
            "1e308",  // Near Double.max
            "1e-308", // Near Double.min
            "1e309",  // Overflow to infinity
        ]
        // Test each case
    }
    
    func testZeroVariants() {
        let cases = ["0", "0.0", "-0", "-0.0", "0e0"]
        // Ensure all parse to 0 consistently
    }
}
```

#### Collection Edge Cases
```swift
// Tests/TOONCoreTests/CollectionEdgeCasesTests.swift
final class CollectionEdgeCasesTests: XCTestCase {
    func testEmptyArray() {
        let toonText = "items[0]:"
        let result = try Parser().parse(toonText)
        XCTAssertEqual(result, .object(["items": .array([])]))
    }
    
    func testSingleItemArray() {
        let toonText = "items[1]: solo"
        // Test inline, tabular, and list formats
    }
    
    func testEmptyObject() {
        let toonText = "container:"
        let result = try Parser().parse(toonText)
        XCTAssertEqual(result, .object(["container": .object(JSONObject())]))
    }
}
```

### Category C: Lenient Mode Coverage

**Target:** All `if options.lenientArrays` branches

```swift
// Tests/TOONCoreTests/LenientModeTests.swift
final class LenientModeTests: XCTestCase {
    func testLenientPadsShortTabularRow() {
        // Cover: Parser line XXX - pad with nulls
        let toonText = """
        items[2]{a,b,c}:
          1,2,3
          4,5
        """
        let parser = Parser(options: .init(lenientArrays: true))
        let result = try parser.parse(toonText)
        // Verify second row padded with null
    }
    
    func testLenientTruncatesLongListArray() {
        // Cover: Parser line YYY - ignore extra items
        let toonText = """
        items[2]:
          - first
          - second
          - extra
        """
        let parser = Parser(options: .init(lenientArrays: true))
        let result = try parser.parse(toonText)
        // Verify only first 2 items kept
    }
}
```

### Category D: Schema Validation Coverage

**Target:** All ToonSchema constraint checks

```swift
// Tests/TOONCodableTests/SchemaValidationTests.swift
final class SchemaValidationTests: XCTestCase {
    func testMissingRequiredField() {
        let schema = ToonSchema.object(fields: [
            .field("required", .string)
        ], allowAdditionalKeys: false)
        
        let toonText = "optional: value"
        let decoder = ToonDecoder(options: .init(schema: schema))
        XCTAssertThrowsError(try decoder.decode([String: String].self, from: Data(toonText.utf8)))
    }
    
    func testUnexpectedFieldWithStrictSchema() {
        let schema = ToonSchema.object(fields: [
            .field("expected", .string)
        ], allowAdditionalKeys: false)
        
        let toonText = """
        expected: value
        unexpected: extra
        """
        let decoder = ToonDecoder(options: .init(schema: schema))
        XCTAssertThrowsError(try decoder.decode([String: String].self, from: Data(toonText.utf8)))
    }
    
    func testNestedSchemaValidation() {
        let schema = ToonSchema.object(fields: [
            .field("nested", .object(fields: [
                .field("inner", .number)
            ], allowAdditionalKeys: false))
        ], allowAdditionalKeys: false)
        
        let toonText = """
        nested:
          inner: not_a_number
        """
        let decoder = ToonDecoder(options: .init(schema: schema))
        XCTAssertThrowsError(try decoder.decode([String: [String: Int]].self, from: Data(toonText.utf8)))
    }
}
```

### Category E: CLI Error Handling Coverage

**Target:** All CLI error paths, pipe handling, I/O failures

```swift
// Tests/TOONCLITests/CLIErrorHandlingTests.swift
final class CLIErrorHandlingTests: XCTestCase {
    func testInvalidFlagProducesError() {
        // Cover: CLI line XXX - unknown flag handling
        let result = shell("toon-swift encode --invalid-flag input.json")
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("Unknown option"))
    }
    
    func testMissingInputFileProducesError() {
        let result = shell("toon-swift encode nonexistent.json")
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stderr.contains("No such file"))
    }
    
    func testBrokenPipeHandling() {
        // Cover: CLI line YYY - SIGPIPE handling
        // Test by piping to head -n 1 and ensure graceful exit
    }
}
```

## Phase 3: CI Threshold Ratcheting

### Batch 1: 85% → 88% (Error Paths)
```yaml
# .github/workflows/ci.yml
- name: Check coverage thresholds
  run: |
    swift Scripts/check-coverage.swift \
      --profile "$PROFILE" \
      --binary-root .build \
      --check "Sources/TOONCore:88:80" \
      --check "Sources/TOONCodable:88:80"
```

**Commit:** "test: add error path coverage (85→88%)"

### Batch 2: 88% → 91% (Edge Cases)
**Commit:** "test: add edge case coverage (88→91%)"

### Batch 3: 91% → 94% (Lenient Mode + Schema)
**Commit:** "test: add lenient mode and schema validation coverage (91→94%)"

### Batch 4: 94% → 97% (CLI + Streaming)
**Commit:** "test: add CLI error handling and streaming coverage (94→97%)"

### Batch 5: 97% → 99% (Final Gaps)
**Commit:** "test: achieve 99%/97% coverage target"

## Phase 4: Document Untestable Code

### Coverage Exceptions Document

Create `docs/coverage-exceptions.md`:

```markdown
# Coverage Exceptions

Lines that cannot achieve coverage and why:

## TOONCore/Parser.swift

### Lines 500-505: Platform-specific error formatting
```swift
#if os(Linux)
    // Linux-specific error formatting
#else
    // macOS-specific error formatting
#endif
```
**Reason:** CI runs on single platform, cannot cover both branches
**Mitigation:** Manual testing on Linux in local dev environment
**Issue:** #123

## TOONCodable/ToonDecoder.swift

### Line 750: Defensive impossible state
```swift
fatalError("Unreachable: schema validation prevents this")
```
**Reason:** Schema validator guarantees this code path is never reached
**Mitigation:** Extensive schema validator tests prove this is unreachable
**Issue:** N/A (by design)
```

### Inline Documentation

Add coverage exemption comments:

```swift
// Coverage: exempt - platform-specific code, tested manually on Linux
#if os(Linux)
    let errorFormat = linuxFormat(error)
#else
    let errorFormat = macosFormat(error)
#endif

// Coverage: exempt - defensive impossible state, schema prevents this path
guard schemaValid else {
    fatalError("Schema validation should prevent this")
}
```

## Automation & Reporting

### Local Coverage Script

Create `Scripts/coverage-report.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 Running tests with coverage..."
swift test --enable-code-coverage --parallel

PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)

echo "📊 Generating coverage report..."
swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts

echo "📈 Coverage Summary:"
cat coverage-artifacts/coverage-summary.json | jq '.lines.percent, .functions.percent, .regions.percent'

echo "🎯 Checking thresholds..."
swift Scripts/check-coverage.swift \
  --profile "$PROFILE" \
  --binary-root .build \
  --check "Sources/TOONCore:99:97" \
  --check "Sources/TOONCodable:99:97"

echo "✅ Coverage check complete!"
```

### GitHub Actions HTML Report

Update `.github/workflows/coverage.yml`:

```yaml
- name: Generate HTML coverage report
  run: |
    PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)
    xcrun llvm-cov show .build/debug/SwiftTOONPackageTests.xctest/Contents/MacOS/SwiftTOONPackageTests \
      -instr-profile="$PROFILE" \
      Sources/TOONCore Sources/TOONCodable \
      -format=html \
      -output-dir=coverage-artifacts/report

- name: Publish coverage report
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./coverage-artifacts
    destination_dir: coverage
```

### README Badge Update

After reaching 99%:

```markdown
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-badge.json&cacheSeconds=600)](https://joelklabo.github.io/SwiftTOON/coverage/report/)
```

Badge will show 99%+ and link to full HTML report.

## Success Metrics

- [ ] TOONCore: ≥99% line, ≥97% branch
- [ ] TOONCodable: ≥99% line, ≥97% branch
- [ ] All uncovered lines documented in exceptions
- [ ] CI enforces 99%/97% thresholds
- [ ] HTML report published to gh-pages
- [ ] Coverage badge shows 99%+

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. Analysis | 1-2 days | coverage-gaps.md + HTML reports |
| 2. Tests (A-E) | 5-7 days | 5 batches of test commits |
| 3. Ratcheting | Continuous | CI threshold at 99%/97% |
| 4. Documentation | 1 day | coverage-exceptions.md |
| **Total** | **7-10 days** | **99%+ coverage** |
