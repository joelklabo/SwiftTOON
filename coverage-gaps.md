# Coverage Gaps Analysis

**Generated:** 2025-11-16  
**Current Coverage:** 90.92% lines, 88.26% functions, 84.11% regions  
**Target:** 99% lines, 97% branches

## TOONCore (84.11% → 99%)

### Parser.swift (77.45% lines → 99%)
**Priority: HIGH** - Largest gap, core functionality

Coverage: 368 total lines, 83 uncovered (77.45% covered)
- **Missing:** Error paths, lenient mode branches, edge cases
- **Focus Areas:**
  - List array parsing with optional length
  - Lenient mode padding/truncation logic
  - Error recovery paths
  - Nested object/array edge cases

### ParserPerformanceTracker.swift (73.68% lines → 99%)
**Priority: MEDIUM** - Performance instrumentation

Coverage: 19 total lines, 5 uncovered (73.68% covered)
- **Missing:** Likely conditional compilation or debug-only paths
- **Focus Areas:**
  - Performance tracking disabled paths
  - Signpost initialization failures

### PerformanceSignpost.swift (66.67% lines → 99%)
**Priority: LOW** - Small file, performance instrumentation

Coverage: 6 total lines, 2 uncovered (66.67% covered)
- **Missing:** Likely platform-specific or disabled signpost paths
- **Candidate for exemption:** Platform-specific code

### Lexer.swift (86.36% lines → 99%)
**Priority: MEDIUM**

Coverage: 176 total lines, 24 uncovered (86.36% covered)
- **Missing:** Error paths, malformed input handling
- **Focus Areas:**
  - Invalid UTF-8 sequences
  - Unterminated strings
  - Malformed escape sequences
  - Numeric overflow/underflow

### JSONTextParser.swift (83.67% lines → 99%)
**Priority: MEDIUM**

Coverage: 147 total lines, 24 uncovered (83.67% covered)
- **Missing:** Error handling, edge cases
- **Focus Areas:**
  - Malformed JSON structures
  - Nested depth limits
  - Unicode edge cases

### JSONValue+Foundation.swift (86.21% lines → 99%)
**Priority: LOW** - Small file

Coverage: 29 total lines, 4 uncovered (86.21% covered)
- **Missing:** Edge cases in Foundation conversion
- **Focus Areas:**
  - NSNull handling
  - Type conversion errors

### JSONObject.swift (89.47% lines → 99%)
**Priority: LOW** - Already high coverage

Coverage: 38 total lines, 4 uncovered (89.47% covered)
- **Missing:** Minor edge cases
- **Focus Areas:**
  - Key collision handling
  - Capacity growth edge cases

---

## TOONCodable (Coverage varies 0%-100%)

### String+TOONUtils.swift (0.00% lines → 99%)
**Priority: CRITICAL** - Zero coverage!

Coverage: 11 total lines, 11 uncovered (0% covered)
- **Missing:** ENTIRE FILE UNTESTED
- **Focus Areas:**
  - `indentString(count:)` function
  - `stripIndent(count:)` function
  - All branches and edge cases

**Action Required:** Immediate test addition

### JSONValueDecoder.swift (68.33% lines → 99%)
**Priority: HIGH** - Core decoder

Coverage: 180 total lines, 57 uncovered (68.33% covered)
- **Missing:** Error paths, schema validation, edge cases
- **Focus Areas:**
  - Schema mismatch handling
  - Nested container decoding
  - Optional field handling
  - Custom CodingKeys
  - Type conversion failures

### JSONValueEncoder.swift (72.22% lines → 99%)
**Priority: HIGH** - Core encoder

Coverage: 90 total lines, 25 uncovered (72.22% covered)
- **Missing:** Error paths, edge cases
- **Focus Areas:**
  - Schema validation failures
  - Nested encoding edge cases
  - Custom encoding strategies

### ToonCodable.swift (76.36% lines → 99%)
**Priority: MEDIUM**

Coverage: 55 total lines, 13 uncovered (76.36% covered)
- **Missing:** Public API error paths
- **Focus Areas:**
  - ToonDecoder initialization failures
  - ToonEncoder edge cases
  - InputStream decoding failures

### ToonSchema.swift (76.92% lines → 99%)
**Priority: MEDIUM**

Coverage: 65 total lines, 15 uncovered (76.92% covered)
- **Missing:** Schema validation logic
- **Focus Areas:**
  - Missing required fields
  - Unexpected fields with strict schema
  - Nested schema mismatches
  - Array element validation

### ToonAnalyzer.swift (91.11% lines → 99%)
**Priority: LOW** - Already high coverage

Coverage: 45 total lines, 4 uncovered (91.11% covered)
- **Missing:** Minor analyzer edge cases
- **Focus Areas:**
  - Mixed-type array detection
  - Sparse object analysis

### ToonSerializer.swift (92.19% lines → 99%)
**Priority: LOW** - Already high coverage

Coverage: 128 total lines, 10 uncovered (92.19% covered)
- **Missing:** Minor serialization edge cases
- **Focus Areas:**
  - Delimiter conflicts
  - Key quoting edge cases

### ToonQuoter.swift (94.38% lines → 99%)
**Priority: LOW** - Already high coverage

Coverage: 89 total lines, 5 uncovered (94.38% covered)
- **Missing:** String quoting edge cases

### ScalarFormatter.swift (94.44% lines → 99%)
**Priority: LOW** - Recently added, high coverage

Coverage: 36 total lines, 2 uncovered (94.44% covered)
- **Missing:** Minor numeric formatting edge cases

### ToonKeyQuoter.swift (94.12% lines → 99%)
**Priority: LOW** - Already high coverage

Coverage: 34 total lines, 2 uncovered (94.12% covered)
- **Missing:** Key quoting edge cases

---

## Category Assignments for Phase 2

### Category A: Error Path Coverage (Target: 85% → 88%)
**Files to Focus:**
- Parser.swift - error paths
- Lexer.swift - malformed input
- JSONValueDecoder.swift - schema mismatches
- JSONTextParser.swift - malformed JSON
- ToonCodable.swift - initialization failures

**Estimated Impact:** +3% coverage

### Category B: Edge Case Coverage (Target: 88% → 91%)
**Files to Focus:**
- Parser.swift - empty arrays, single items, nested depth
- Lexer.swift - numeric boundaries, zero variants
- JSONValue+Foundation.swift - type conversions
- JSONValueEncoder.swift - nested encoding
- String+TOONUtils.swift - **CRITICAL: add any tests**

**Estimated Impact:** +3% coverage (includes String+TOONUtils 0% → 100%)

### Category C: Lenient Mode Coverage (Target: 91% → 93%)
**Files to Focus:**
- Parser.swift - `if options.lenientArrays` branches
- All padding/truncation logic
- Strict vs lenient comparisons

**Estimated Impact:** +2% coverage

### Category D: Schema Validation Coverage (Target: 93% → 95%)
**Files to Focus:**
- ToonSchema.swift - all validation paths
- JSONValueDecoder.swift - schema enforcement
- ToonCodable.swift - schema option paths

**Estimated Impact:** +2% coverage

### Category E: CLI Error Handling (Target: 95% → 97%)
**Files to Focus:**
- TOONCLI (not analyzed above, separate target)
- File I/O errors
- Pipe handling
- Invalid arguments

**Estimated Impact:** +2% coverage

### Final Push (Target: 97% → 99%)
**Files to Focus:**
- ParserPerformanceTracker.swift
- PerformanceSignpost.swift (may be exempt)
- All remaining uncovered lines
- Platform-specific code documentation

**Estimated Impact:** +2% coverage

---

## Summary Statistics

| Module | Current | Target | Gap | Priority Files |
|--------|---------|--------|-----|----------------|
| TOONCore | 84.11% | 99% | +14.89% | Parser (77%), ParserPerf (74%), Lexer (86%) |
| TOONCodable | ~85% | 99% | +14% | String+TOON (0%), JSONValueDecoder (68%), JSONValueEncoder (72%) |

**Total Uncovered Lines:** ~230-250 lines across both modules  
**Estimated Test Cases Needed:** 60-80 tests across 5 categories  
**Timeline:** 7-10 days with systematic approach

---

## Next Steps

1. ✅ Task 1.1: Generate coverage reports (DONE)
2. ✅ Task 1.2: Analyze uncovered lines (DONE)
3. ✅ Task 1.3: Create this coverage-gaps.md (DONE)
4. → Task 2.A: Start Category A tests (Error Paths)
5. → Focus: String+TOONUtils.swift (0% coverage is unacceptable)
