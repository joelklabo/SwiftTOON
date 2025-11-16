# Coverage Gaps Analysis - Stage 10 Phase 1
**Generated:** 2025-11-16T16:57 UTC  
**Agent:** Copilot-CLI-Coverage  
**Overall Coverage:** 89.7% lines, 87.0% functions, 82.7% regions

## Summary

Current coverage is **89.7% lines**, short of the **99% goal** by **9.3 percentage points**.

### Critical Gaps (Priority 1 - Below 85%)

| File | Line % | Missing | Focus Area |
|------|--------|---------|------------|
| **TOONCore/Parser.swift** | 83.3% | 112 lines | Parser error paths, edge cases |
| **TOONCLI/main.swift** | 80.1% | 80 lines | CLI error handling, invalid inputs |
| **TOONCodable/ToonCodable.swift** | 79.5% | 23 lines | Encoder/decoder edge cases |
| **TOONCodable/JSONValueDecoder.swift** | 75.5% | 45 lines | Decode failures, type mismatches |
| **TOONCore/ParserPerformanceTracker.swift** | 69.1% | 21 lines | Perf tracking edge cases |
| **TOONCore/PerformanceSignpost.swift** | 50.0% | 5 lines | Signpost branches |
| **TOONCodable/String+TOONUtils.swift** | 0.0% | 16 lines | **COMPLETELY UNTESTED!** |

### Moderate Gaps (Priority 2 - 85-95%)

| File | Line % | Missing | Focus Area |
|------|--------|---------|------------|
| **TOONCodable/JSONValueEncoder.swift** | 89.7% | 25 lines | Container encoding paths |
| **TOONCore/Lexer.swift** | 89.7% | 31 lines | Invalid token edge cases |
| **TOONCodable/ToonSchema.swift** | 90.5% | 9 lines | Schema validation failures |
| **TOONCore/JSONValue+Foundation.swift** | 91.3% | 4 lines | Foundation conversion edges |
| **TOONCore/JSONTextParser.swift** | 93.2% | 15 lines | JSON parsing edge cases |
| **TOONBenchmarks/Benchmarks.swift** | 93.1% | 13 lines | Benchmark error paths |

### Near Complete (Priority 3 - 95%+)

These are close to goal but need final edge case coverage:
- **TOONCodable/ScalarFormatter.swift** (94.6%) - 3 lines
- **TOONCodable/ToonKeyQuoter.swift** (95.5%) - 2 lines
- **TOONCore/JSONObject.swift** (95.9%) - 3 lines
- **TOONCodable/ToonAnalyzer.swift** (96.1%) - 3 lines
- **TOONCodable/ToonSerializer.swift** (98.5%) - 6 lines
- **TOONCodable/ToonQuoter.swift** (99.0%) - 1 line

### Perfect Coverage (Reference)

These files already meet/exceed goal:
- **TOONCodable/AnyCodingKey.swift** (100%)
- **TOONCodable/ToonEncodingOptions.swift** (100%)

---

## Detailed Gap Analysis by Module

### TOONCore (Most Critical)

#### 1. Parser.swift (83.3% - **HIGHEST PRIORITY**)
**Missing:** 112 lines  
**Focus Areas:**
- Error handling in list array parsing
- Malformed indentation edge cases
- Invalid array length declarations
- Nested depth limit edge cases
- Lenient mode recovery paths
- Parser state transitions on invalid input

**Recommended Tests:**
- `testParserRejectsInvalidIndentationPatterns()`
- `testParserHandlesMalformedArrayLengths()`
- `testParserEnforcesNestingDepthLimits()`
- `testLenientModeRecoveryFromInvalidRows()`
- `testParserStateAfterErrors()`

#### 2. Lexer.swift (89.7%)
**Missing:** 31 lines  
**Focus Areas:**
- Invalid escape sequences
- Unterminated strings
- Edge case numeric formats (very large/small, special values)
- Token boundary edge cases

**Recommended Tests:**
- `testLexerRejectsInvalidEscapes()`
- `testLexerHandlesUnterminatedStrings()`
- `testLexerEdgeCaseNumbers()` (NaN, Inf, MAX_INT, etc.)

#### 3. PerformanceSignpost.swift (50.0% - **COMPLETELY TESTABLE**)
**Missing:** 5 lines  
This is purely perf instrumentation - likely just missing test coverage for enabled/disabled states.

**Recommended Tests:**
- `testSignpostWhenPerformanceTrackingEnabled()`
- `testSignpostWhenPerformanceTrackingDisabled()`

---

### TOONCodable (Second Priority)

#### 1. String+TOONUtils.swift (0.0% - **CRITICAL UNTESTED CODE!**)
**Missing:** ALL 16 lines  
This utility was just added and has NO test coverage!

**Immediate Action Required:**
- Add `Tests/TOONCodableTests/StringUtilsTests.swift`
- Test `indentString(count:)` with various indent levels
- Test `stripIndent(count:)` with edge cases (zero, beyond length, etc.)

#### 2. JSONValueDecoder.swift (75.5%)
**Missing:** 45 lines  
**Focus Areas:**
- Decode type mismatches (string → number, etc.)
- Missing required keys
- Invalid container access patterns
- Nested container failures

**Recommended Tests:**
- `testDecodeTypeMismatch()`
- `testDecodeMissingRequiredKey()`
- `testDecodeInvalidContainerAccess()`
- `testDecodeNestedContainerFailures()`

#### 3. JSONValueEncoder.swift (89.7%)
**Missing:** 25 lines  
**Focus Areas:**
- All Swift type combinations
- Nested container edge cases
- Super encoder paths

**Recommended Tests:**
- `testEncodeAllSwiftTypes()` (Int8/16/32/64, UInt variants, Float, Double)
- `testEncodeNestedContainers()`
- `testEncodeSuperEncoder()`

#### 4. ToonCodable.swift (79.5%)
**Missing:** 23 lines  
**Focus Areas:**
- ToonEncoder/ToonDecoder initialization edge cases
- Options handling
- Error paths

---

### TOONCLI (Functional, Not Critical)

#### main.swift (80.1%)
**Missing:** 80 lines  
**Focus Areas:**
- Invalid command-line flags
- Missing input files
- STDIN/STDOUT error conditions
- Pipe failures

**Recommended Tests:**
These are likely already tested in integration tests, but line coverage might not be counting them. Consider:
- `testCLIInvalidFlags()`
- `testCLIMissingInputFile()`
- `testCLIPipeFailures()`

---

## Action Plan

### Phase 1.1: Critical Gaps (This Sprint)
1. ✅ **DONE:** Generate this report
2. **NEXT:** Add tests for `String+TOONUtils.swift` (0% → 100%)
3. **NEXT:** Add Parser.swift error path tests (83% → 90%)
4. **NEXT:** Add JSONValueDecoder.swift failure tests (75% → 85%)

### Phase 1.2: Moderate Gaps
5. Add Lexer.swift edge case tests (89% → 95%)
6. Add JSONValueEncoder.swift comprehensive type tests (89% → 95%)
7. Add ToonCodable.swift error tests (79% → 90%)

### Phase 1.3: Near-Perfect Files
8. Complete remaining 1-6 line gaps in near-perfect files (95% → 100%)

### Phase 1.4: CLI Coverage
9. Verify CLI integration test coverage is being counted properly
10. Add missing CLI error handling tests if needed

---

## Estimated Impact

| Phase | Target | Lines to Add | Est. Tests | Impact |
|-------|--------|--------------|------------|--------|
| 1.1 (Critical) | +10% | ~180 lines | ~15 tests | 89.7% → 92%+ |
| 1.2 (Moderate) | +5% | ~80 lines | ~10 tests | 92% → 95%+ |
| 1.3 (Final) | +4% | ~30 lines | ~10 tests | 95% → 99%+ |
| **Total** | **+19.3%** | **~290 lines** | **~35 tests** | **89.7% → 99%** |

---

## Next Steps

1. Commit this report
2. Update `docs/plan.md` Phase 1 checklist as complete
3. Move to Phase 2: Start adding tests for critical gaps
4. Track progress: run coverage after each batch of 5-10 tests
5. Ratchet CI gates incrementally (90% → 95% → 99%)
