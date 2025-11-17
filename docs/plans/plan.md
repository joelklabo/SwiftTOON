# SwiftTOON Implementation Plan

**Current Status:** Stage 11 (Performance Optimization) - Phases 1-3 Complete  
**Release:** v0.1.3  
**Coverage:** 92.35% line (556 tests)  
**Next:** Stage 11 Phase 4 - Schema-primed fast path demonstration

---

## Project Goals

- **TOONCore** – Zero-dependency lexer, parser, serializer, error taxonomy, `JSONValue` intermediate representation
- **TOONCodable** – Swift `Codable` bridges, schema-primed fast paths, JSON utilities
- **TOONCLI** – `toon-swift` executable for encode/decode/validate/stats/bench operations
- **TOONBenchmarks** – Performance benchmarks integrated into test suite

**Targets:**
- Strict TOON v2 spec compliance (commit 3d6c593)
- Zero third-party dependencies
- ≥99% line + ≥97% branch coverage
- Throughput within ±10% of TypeScript reference
- Byte-for-byte parity on all official fixtures

---

## Completed Stages (0-9)

### Stage 0 – Inputs & Guardrails ✅
- Fixture generator tooling (`Scripts/update-fixtures.swift`)
- Reference CLI bridge for differential testing
- Performance baseline harness
- In-repo coverage pipeline (replaces Codecov)
- Badge publishing to `gh-pages/`

### Stage 1 – Workspace Scaffolding ✅
- SwiftPM package with all targets
- DocC bundle + README
- CHANGELOG.md, CONTRIBUTING.md
- CLI integration tests

### Stage 2 – Lexer ✅
- `UnsafeRawBufferPointer`-driven scanner
- Comprehensive token tests (identifiers, numbers, strings, escape sequences, indentation)
- **Coverage:** 97.68% line
- **Performance:** 5.40 MB/s (+19.9% vs baseline)

### Stage 3 – Parser ✅
- Recursive-descent parser with indentation stack
- Tabular array support (length tokens, header validation, row counting)
- List array support (dash entries, `[N]:` inline definitions, nesting)
- Lenient mode (padding/truncation when requested)
- Error taxonomy with line/column context
- **Coverage:** 91.64% line
- **Performance:** 2.67 MB/s (-9.3% regression vs baseline) ⚠️

### Stage 4 – Decoder Integration ✅
- `JSONValue` intermediate representation
- `JSONValueDecoder` implementing Swift's `Decoder` protocol
- Streaming decoder support
- Schema validation paths
- **Coverage:** 91.30% line
- **Performance:** 3.14 MB/s decode end-to-end (-17.3% regression) ⚠️

### Stage 5 – Encoder ✅
- Structure analyzer (inline/tabular/list heuristics)
- `ToonSerializer` with delimiter/indent/key-folding options
- Deterministic output (field order, quoting, number formatting)
- Encode fixture suite (round-trip validated)
- **Coverage:** >95% line

### Stage 6 – Codable Bridges & Schema Priming ✅
- `ToonEncoder` and `ToonDecoder`
- Custom `JSONValue` coders (no `JSONSerialization` hop)
- `ToonSchema` for validation + fast-path hints
- Schema-aware regression tests
- **Coverage:** 96.52% line

### Stage 7 – CLI & UX ✅
- `toon-swift` commands: encode, decode, validate, stats, bench
- STDIN/STDOUT streaming
- Flags: `--delimiter`, `--indent`, `--lenient`
- Help text snapshots
- Integration tests covering all commands
- **Coverage:** 80.15% line

### Stage 8 – Testing & Automation ✅
- Golden fixture round-trip tests (encode ↔ decode)
- Differential tests vs TypeScript CLI
- CI coverage gates (≥85% TOONCore, ≥78% TOONCodable)
- Sanitizers: AddressSanitizer + ThreadSanitizer on macOS
- Fuzz testing (Darwin-only TOON lexeme fuzzer)
- Performance regression guard (±20% tolerance in CI)
- Automated perf/coverage publishing to `gh-pages/`

### Stage 9 – Documentation & Release ✅
- DocC tutorials: "Getting Started", "Tabular Arrays", "Schema Priming"
- Spec alignment checker (`Scripts/check-spec-alignment.swift`)
- Spec version documented (v2.0.0 / commit 3d6c593)
- Release checklist automation
- v0.1.3 released (2025-11-16)

---

## Stage 10 – Coverage Excellence (92.35% → 95%+)

**Status:** ✅ Major progress achieved (91.29% → 92.35%), final push to 95%+ pending

### Accomplishments
- **+148 tests** added across 10 new test files (Nov 16 coverage sprint)
- **Parser:** 83.73% → 91.64% (+7.91%) 🏆
- **JSONValueDecoder:** 83.70% → 91.30% (+7.60%)
- **Lexer:** 95.70% → 97.68% (+1.98%)
- **TOONCore:** 88.40% → 92.29% (+3.89%)
- **TOONCodable:** 95.48% → 96.52% (+1.04%)

### Test Files Created
1. ParserRemainingCoverageTests (29 tests)
2. JSONValueDecoderRemainingTests (15 tests)
3. ParserUncoveredPathsTests (21 tests)
4. ParserSurgicalCoverageTests (15 tests)
5. ParserParseValueTriggerTests (10 tests)
6. ParserPerformanceTrackerTests (7 tests)
7. ParserErrorPathsTests (23 tests)
8. LexerEdgeCaseTests (13 tests)
9. ParserFinalGapsTests (13 tests)
10. JSONValueDecoderComprehensiveTests (18 tests)

### Remaining Gaps to 95%+
- **Parser:** ~50 uncovered lines (error paths, edge cases)
- **JSONValueDecoder:** ~16 uncovered lines (nested containers, type conversions)
- **Estimated:** 30-40 additional tests needed

### Next Actions
1. Add remaining Parser edge case tests
2. Complete JSONValueDecoder container tests
3. Push CLI coverage from 80.15% → 90%+
4. Update CI thresholds to lock in 92%+ baseline

---

## Stage 11 – Performance Optimization (CURRENT)

**Goal:** Achieve ±10% parity with TypeScript reference  
**Duration:** 2-3 weeks  
**Status:** Phases 1-3 complete ✅, Phase 4 in progress

### Current Performance Status

**Benchmark Results (Latest - 2025-11-16):**
```
Lexer:   26.83 MB/s (+495.7% vs old baseline) ✅ EXCELLENT
Parser:   5.83 MB/s (+98.4% vs old baseline)  ✅ TARGET EXCEEDED
Decoder:  9.97 MB/s (+162.7% vs old baseline) ✅ TARGET EXCEEDED
Objects:  1235.2 obj/s (+197.9%)              ✅ EXCELLENT
```

**Achievements:**
- ✅ Parser target was 2.94 MB/s - achieved 5.83 MB/s (98% over target!)
- ✅ Decoder target was 3.79 MB/s - achieved 9.97 MB/s (163% over target!)
- ✅ All benchmarks within ±20% tolerance
- ✅ Baseline updated to lock in improvements

**Remaining:**
- Schema-primed: Demonstrate ≥20% gain over default

---

### Phase 1: TypeScript Baseline ✅ COMPLETE

**Deliverables:**
- ✅ TypeScript CLI benchmarked on identical datasets
- ✅ `Benchmarks/baseline_typescript.json` created with throughput targets
- ✅ Performance gap analysis documented

**Results:**
- TypeScript encode: 8.5 MB/s
- TypeScript decode: 6.2 MB/s
- Swift target (90% of TS): 7.65 MB/s encode, 5.58 MB/s decode

---

### Phase 2: Parser Performance Recovery ✅ COMPLETE

**Goal:** Recover to 2.94 MB/s (+10% from baseline)

**Result:** 5.83 MB/s achieved (+98.4% improvement!)

**What Happened:**
The "regression" was comparing against outdated v0.1.1 baseline. Between v0.1.1 and now, 10 performance commits collectively achieved:
- reserve JSONObject buffers
- inline newline handling for list items  
- cache peek tokens
- shortcut single-token rows
- reserve list buffers
- shortcut inline scalars
- inline list parse
- trim buildValue allocation
- publish phase metrics

These optimizations produced the 98% parser improvement.

---

### Phase 3: Decoder Performance Recovery ✅ COMPLETE

**Goal:** Recover to 3.79 MB/s (+21% from baseline)

**Result:** 9.97 MB/s achieved (+162.7% improvement!)

The same optimizations that improved the parser also dramatically improved decode end-to-end performance, as the decoder relies on the parser.

---

### Phase 4: Schema-Primed Fast Path (CURRENT)

**Goal:** Recover -9.3% regression (2.67 → 2.94 MB/s minimum)

#### Step 1: Profile Parser Hotspots

**Option A: Instruments (macOS)**
```bash
swift build -c release
open -a Instruments
# Select "Time Profiler", target .build/release/TOONBenchmarks
# Run parser_micro benchmark
```

Look for:
- Functions consuming >5% time
- Allocation hotspots
- Excessive retain/release

**Option B: Built-in Tracing**
```bash
SWIFTTOON_PERF_TRACE=1 swift run -c release TOONBenchmarks
```

Check phase durations:
- Lexing time
- Parsing time
- Value building time

#### Step 2: Identify Regression Causes

Review recent commits:
```bash
git log --since="2025-11-01" --oneline -- Sources/TOONCore/Parser.swift
```

Check for:
- New allocations in hot loops
- Added function calls in `parseValue()`
- Changes to `parseListArray` / `parseTabularRows`
- Token lookahead overhead

#### Step 3: Optimization Candidates

**A. Buffer Reuse**
```swift
// Add to Parser struct
private var valueBuffer: [JSONValue] = []
private var stringBuffer: String = ""

// In parseTabularRows
valueBuffer.removeAll(keepingCapacity: true)  // Reuse allocation
```

**B. Inline Hot Paths**
```swift
@inlinable
internal func parseValue() throws -> JSONValue {
    // Hot path code
}
```

**C. Reduce Allocations in parseListArray**
```swift
// AFTER (single check, branch prediction friendly)
guard case .dash = token.kind else { ... }
```

**D. Token Lookahead Cache**
```swift
private var lookaheadCache: Token?

mutating func peek() -> Token {
    if let cached = lookaheadCache { return cached }
    lookaheadCache = nextToken()
    return lookaheadCache!
}
```

#### Step 4: Measure Each Change

After each optimization:
```bash
swift run -c release TOONBenchmarks --format json --output Benchmarks/results/temp.json
swift Scripts/compare-benchmarks.swift \
  Benchmarks/results/temp.json \
  Benchmarks/baseline_reference.json \
  --tolerance 0.05

# If improved:
git add ...
git commit -m "perf: reduce parser allocations (+X% throughput)"
```

---

### Phase 4: Schema-Primed Fast Path (CURRENT)

**Goal:** Demonstrate ≥20% speedup with schema hints vs default analyzer

```bash
instruments -t "Time Profiler" \
  .build/release/TOONBenchmarks \
  decode_end_to_end
```

Determine bottleneck:
- Parser? (covered by Phase 2)
- JSONValueDecoder?
- Codable synthesis?

#### Step 2: Optimization Candidates

**A. Container Unwrapping Overhead**
```swift
// Cache container reference
private var cachedContainer: KeyedDecodingContainer<Key>?
```

**B. CodingKey Lookup Cache**
```swift
private var keyCache: [String: JSONValue] = [:]

func decode<T>(_ type: T.Type, forKey key: Key) throws -> T {
    if let cached = keyCache[key.stringValue] {
        return decode(cached)
    }
    // Lookup and cache
}
```

**C. Remove Defensive Copies**
```swift
// AFTER (direct return)
return jsonValue.arrayValue ?? []
```

**D. Optimize Number Decoding**
```swift
@inlinable
func decode(_ type: Int.self) throws -> Int {
    guard case .number(let d) = value, d.rounded() == d else { throw ... }
    return Int(bitPattern: UInt(bitPattern: d.bitPattern >> 32))
}
```

**Target:** Decoder ≥3.79 MB/s (baseline + 21%)

---

### Phase 4: Schema-Primed Fast Path

**Goal:** Demonstrate ≥20% speedup with schema hints vs default analyzer

#### Step 1: Create Schema-Primed Benchmarks

```swift
let userSchema = ToonSchema.object(fields: [
    .field("id", .number),
    .field("name", .string),
    .field("email", .string),
    .field("active", .bool)
])

func benchmarkSchemaEncode() {
    let users = generateUsers(count: 10000)
    let encoder = ToonEncoder(schema: userSchema)
    measure {
        _ = try! encoder.encode(users)
    }
}

func benchmarkDefaultEncode() {
    let users = generateUsers(count: 10000)
    let encoder = ToonEncoder()  // No schema
    measure {
        _ = try! encoder.encode(users)
    }
}
```

#### Step 2: Optimize Schema Path

**A. Skip Analyzer When Schema Provided**
```swift
if let schema = self.schema {
    return try serializeWithSchema(value, schema: schema)
} else {
    let analyzed = try analyzer.analyze(value)
    return try serialize(analyzed)
}
```

**B. Pre-allocate Based on Schema**
```swift
func serializeWithSchema(_ value: Encodable, schema: ToonSchema) throws -> String {
    var output = ""
    output.reserveCapacity(estimateSize(schema: schema, count: valueCount))
    // Direct field serialization
}
```

**C. Direct Field Access**
```swift
// Type known at compile time via schema
for field in schema.fields {
    serializeValue(value, schema: field.schema)
}
```

#### Step 3: Measure Schema Gain

```bash
swift run -c release TOONBenchmarks --format json | jq '
  .benchmarks |
  {
    "default_encode": .default_encode_throughput,
    "schema_encode": .schema_encode_throughput,
    "gain_percent": ((.schema_encode_throughput - .default_encode_throughput) / 
                     .default_encode_throughput * 100)
  }
'
```

**Target:** Schema-primed ≥20% faster than default

---

### Phase 5: Additional Micro-Optimizations

Based on profiling, consider:
- String interning for common keys
- Lazy token parsing
- Buffer pooling for large files
- SIMD for numeric parsing
- Custom allocators for temporary structures

---

### Performance Tracking Workflow

#### Local Performance Workflow
```bash
# Run benchmarks
swift run -c release TOONBenchmarks --format json --output Benchmarks/results/latest.json

# Compare against baseline
swift Scripts/compare-benchmarks.swift \
  Benchmarks/results/latest.json \
  Benchmarks/baseline_reference.json \
  --tolerance 0.05

# Commit if improved
git add Sources/ Benchmarks/baseline_reference.json
git commit -m "perf: <description> (+X% throughput)"
```

#### CI Performance Pipeline
- `perf.yml`: Runs on every push, enforces ±20% tolerance
- `perf-history.yml`: Appends results to history on `main` push
- Artifacts published to `gh-pages/perf/`:
  - `perf-history.json` - Full history
  - `perf-badge.json` - Shields endpoint
  - `perf-history.png` - QuickChart line graph
  - `meta.json` - Repo metadata

#### Performance Iteration History

**Latest Iterations** (documented in performance-tracking.md):

**Iteration #13** – Static empty JSONObject in parseListArrayItem
- ❌ Reverted: No positive impact, slight negative

**Iteration #12** – Increase JSONObject initial capacity (8→16)
- ❌ Reverted: No benefit for current datasets

**Iteration #11** – Reserve JSONObject buffers & phase metrics
- ✅ Success: Added phase duration tracking to benchmarks
- Parser now reserves capacity for objects/tabular rows
- Phase durations now visible in QuickChart graph

**Iteration #9** – Peek caching
- ✅ Success: Reduced repeated `peekToken(offset: 1)` calls
- Cached upcoming token per iteration in parseListArrayItem

---

### Stage 11 Success Criteria

- [ ] TypeScript baseline captured ✅
- [ ] Parser within ±10% of TypeScript
- [ ] Decoder within ±10% of TypeScript
- [ ] Schema-primed ≥20% faster than default
- [ ] All benchmarks passing with new baselines
- [ ] Performance tracking document updated
- [ ] README badges reflect improvements
- [ ] v0.2.0 released (performance release)

**Estimated Timeline:**
- Phase 1 (Baseline): ✅ 1 day (complete)
- Phase 2 (Parser): 2-3 days (next)
- Phase 3 (Decoder): 2-3 days
- Phase 4 (Schema): 2-3 days
- Phase 5 (Micro-opts): Ongoing/optional

---

## Stage 12 – Future Releases

### v0.2.0 (Next)
- Complete Stage 11 performance work
- ±10% TypeScript parity achieved
- Schema-primed benchmarks demonstrated

### v0.3.0 (Future)
- Stage 10 completion (95%+ coverage)
- Enhanced CLI features
- Additional optimization iterations

---

## Performance Tracking Playbook

### Workflow Overview

1. **Author Benchmarks** - Create datasets under `Benchmarks/Datasets/`
2. **Persist Baselines** - Store initial measurements in `Benchmarks/baseline_reference.json`
3. **CI Regression Gate** - `perf.yml` workflow fails build if >20% regression
4. **History Pipeline** - `perf-history.yml` appends results to history JSON
5. **Visualization** - Auto-generate badge + PNG graph published to `gh-pages/`

### Commands Reference

```bash
# Profiling
instruments -t "Time Profiler" .build/release/TOONBenchmarks
SWIFTTOON_PERF_TRACE=1 swift run -c release TOONBenchmarks
instruments -t "Allocations" .build/release/TOONBenchmarks

# Benchmarking
swift run -c release TOONBenchmarks --format json --output results.json
swift Scripts/compare-benchmarks.swift results.json baseline.json --tolerance 0.10

# Watch performance
watch -n 60 'swift run -c release TOONBenchmarks | grep MB/s'

# Build optimized
swift build -c release -Xswiftc -enforce-exclusivity=checked
```

---

## Coverage Tracking Playbook

### Local Workflow

```bash
# Run tests with coverage
swift test --enable-code-coverage --parallel

# Find profile
PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)

# Generate summary
swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts
cat coverage-artifacts/coverage-summary.json

# Check thresholds
swift Scripts/check-coverage.swift \
  --profile "$PROFILE" \
  --binary-root .build \
  --check "Sources/TOONCore:99:97" \
  --check "Sources/TOONCodable:99:97"
```

### CI Workflow

- `ci.yml`: Swift tests + sanitizers (always runs)
- `coverage.yml`: Badge generation (triggers on `main` push)
- Publishes to `gh-pages/coverage/`:
  - `coverage-badge.json` - Shields endpoint
  - `coverage-summary.json` - Full metrics

---

## Success Criteria (Project Complete)

- ✅ 100% of official fixtures pass (encode + decode)
- ⏳ Throughput within ±10% of TypeScript (Stage 11)
- ⏳ Coverage ≥99% line / ≥97% branch (Stage 10)
- ✅ CLI + library share identical code paths
- ✅ Zero third-party dependencies
- ✅ Comprehensive documentation (DocC + README)
- ✅ Automated CI/CD pipeline with perf + coverage gates

---

**Last Updated:** 2025-11-16 (Stage 11 Phase 1 complete)
