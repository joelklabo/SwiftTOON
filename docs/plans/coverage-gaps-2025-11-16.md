# Coverage Gaps Analysis - 2025-11-16

**Current Overall:** 92.73% lines / 86.67% regions  
**Target:** 95%+ lines / 90%+ regions (stretch: 99%/97%)

## Priority Modules (Sorted by Gap Size)

### 1. ToonSchema.swift ⚠️ LOWEST
- **Current:** 76.92% regions / 90.53% lines
- **Gap:** 15 missed regions, 9 missed lines
- **Priority:** HIGH (biggest gap)
- **Focus Areas:**
  - Schema validation edge cases
  - Nested schema traversal
  - Error reporting for schema mismatches
  - Optional vs required field handling

### 2. JSONTextParser.swift
- **Current:** 83.67% regions / 93.15% lines
- **Gap:** 24 missed regions, 15 missed lines
- **Priority:** HIGH
- **Focus Areas:**
  - JSON escape sequence edge cases
  - Unicode handling (surrogate pairs)
  - Numeric parsing edge cases (exponents, leading zeros)
  - Error recovery paths

### 3. JSONValueDecoder.swift
- **Current:** 82.22% regions / 91.30% lines
- **Gap:** 32 missed regions, 16 missed lines
- **Priority:** HIGH
- **Focus Areas:**
  - Nested container decoding edge cases
  - Type conversion error paths
  - superDecoder edge cases
  - Container boundary conditions

### 4. Parser.swift
- **Current:** 85.33% regions / 91.64% lines
- **Gap:** 54 missed regions, 56 missed lines
- **Priority:** MEDIUM (many lines but already improved significantly)
- **Focus Areas:**
  - Remaining error paths
  - Edge cases in tabular/list array handling
  - Lenient mode branches
  - EOF handling in complex scenarios

### 5. TOONCLI/main.swift
- **Current:** 71.12% regions / 80.15% lines
- **Gap:** 67 missed regions, 80 missed lines
- **Priority:** LOW (CLI, acceptable coverage for user-facing code)
- **Note:** CLI coverage is acceptable; focus on core library

## Moderate Coverage (85-95%) - Refinement Targets

### ParserPerformanceTracker.swift
- **Current:** 73.68% regions / 69.12% lines
- **Gap:** 5 missed regions, 21 missed lines
- **Priority:** LOW (observability/debugging code, acceptable)

### JSONObject.swift
- **Current:** 89.47% regions / 95.89% lines
- **Gap:** 4 missed regions, 3 missed lines
- **Priority:** LOW (nearly complete)

### ToonAnalyzer.swift
- **Current:** 91.11% regions / 96.05% lines
- **Gap:** 4 missed regions, 3 missed lines
- **Priority:** LOW (nearly complete)

### ToonSerializer.swift
- **Current:** 92.19% regions / 98.45% lines
- **Gap:** 10 missed regions, 6 missed lines
- **Priority:** LOW (excellent coverage)

### TOONBenchmarks/Benchmarks.swift
- **Current:** 88.89% regions / 93.12% lines
- **Gap:** 5 missed regions, 13 missed lines
- **Priority:** LOWEST (benchmark infrastructure, acceptable)

## Excellent Coverage (95%+) - Maintain

- **ToonSerializer.swift**: 98.45% lines ⭐
- **ToonQuoter.swift**: 99.00% lines ⭐
- **JSONValueEncoder.swift**: 98.35% lines ⭐
- **ToonCodable.swift**: 97.32% lines ⭐
- **Lexer.swift**: 97.68% lines ⭐

## Action Plan to Reach 95%+

### Phase 1: ToonSchema Coverage Boost (90.53% → 98%+)
**Impact:** +0.3% overall (9 lines × high importance)

**Tests to Add:**
1. Schema validation with nested objects (3+ levels deep)
2. Schema mismatch error messages (wrong type, missing field, extra field)
3. Optional field handling (present, absent, null)
4. Array schema validation (uniform vs mixed types)
5. Schema equality/hashing edge cases

**Estimated Tests:** 15-20 tests

### Phase 2: JSONTextParser Edge Cases (93.15% → 97%+)
**Impact:** +0.5% overall (15 lines)

**Tests to Add:**
1. Unicode escape sequences (\\uXXXX, surrogate pairs)
2. All escape characters (\\t, \\r, \\n, \\", \\\\, \\/)
3. Scientific notation edge cases (1e-308, 1e308)
4. Numeric edge cases (leading zeros, -0, trailing decimals)
5. Malformed JSON error recovery

**Estimated Tests:** 10-15 tests

### Phase 3: JSONValueDecoder Refinement (91.30% → 96%+)
**Impact:** +0.5% overall (16 lines)

**Tests to Add:**
1. Nested unkeyed/keyed container combinations
2. superDecoder with non-standard keys
3. Type mismatch error paths (expecting int, got string)
4. Empty container edge cases
5. Container decoding at max depth

**Estimated Tests:** 10-15 tests

### Phase 4: Parser Final Polish (91.64% → 94%+)
**Impact:** +1.7% overall (56 lines)

**Tests to Add:**
1. Remaining lenient mode branches
2. Complex EOF scenarios (mid-array, mid-object)
3. Malformed tabular array error paths
4. Deep nesting edge cases
5. Whitespace/indent edge cases

**Estimated Tests:** 20-25 tests

## Total Effort Estimate

- **Tests to Add:** 55-75 tests
- **Coverage Gain:** +3.0% to +3.5% (92.73% → 95.7-96.2%)
- **Time Estimate:** 2-3 focused sessions
- **Priority Order:** Phase 1 → Phase 2 → Phase 3 → Phase 4

## Success Criteria

- [x] Overall line coverage ≥92% (current: 92.73%)
- [ ] Overall line coverage ≥95% (target)
- [ ] TOONCore line coverage ≥95% (current: 92.29%)
- [ ] TOONCodable line coverage ≥95% (current: 96.52% ✅)
- [ ] Region coverage ≥90% (current: 86.67%)
- [ ] Zero regressions in existing tests
- [ ] All new tests pass and are documented

## Next Steps

1. Start with Phase 1 (ToonSchema) - highest ROI per test
2. Generate HTML coverage report to identify exact lines
3. Write failing tests first (TDD)
4. Implement/fix to make tests pass
5. Verify coverage increase after each phase
6. Update this document with progress

---

**Last Updated:** 2025-11-16 21:35 UTC  
**Agent:** GitHub Copilot CLI  
**Coverage Tool:** llvm-cov (Swift native)
