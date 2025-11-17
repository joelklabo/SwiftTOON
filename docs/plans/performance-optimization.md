# Stage 11: Performance Optimization - Detailed Execution Plan

**Goal:** Achieve ±10% parity with TypeScript reference (currently ±20%)  
**Duration:** 2-3 weeks  
**Current Status:** Benchmarks exist, ±20% tolerance passing

---

## Current Performance Status

### Benchmark Results (Latest)
```
Lexer:   5.40 MB/s  (+19.9% vs baseline) ✅ GOOD
Parser:  2.67 MB/s  (-9.3% regression)   ⚠️  NEEDS RECOVERY
Decoder: 3.14 MB/s  (-17.3% regression)  ⚠️  NEEDS RECOVERY
```

### Target: ±10% Tolerance
- Lexer: Maintain current performance
- Parser: Recover to 2.94 MB/s (+10%)
- Decoder: Recover to 3.79 MB/s (+21%)
- Schema-primed: Demonstrate ≥20% gain over default

---

## Phase 1: Establish TypeScript Baseline (Day 1)

### Goal
Compare Swift performance against reference TypeScript CLI on identical datasets.

### Tasks

#### 1.1: Benchmark TypeScript CLI
```bash
cd reference
pnpm install
pnpm build

# Run TypeScript benchmarks
time node packages/cli/dist/index.js encode < ../Benchmarks/Datasets/large_uniform.json > /dev/null
time node packages/cli/dist/index.js decode < ../Benchmarks/Datasets/large_uniform.toon > /dev/null
```

Record:
- Encode throughput (MB/s)
- Decode throughput (MB/s)
- Memory usage
- Time for each dataset

#### 1.2: Create TypeScript Baseline File
```bash
cat > Benchmarks/baseline_typescript.json << 'JSON'
{
  "timestamp": "2025-11-16T23:00:00Z",
  "version": "toon-format@2.0.0",
  "commit": "3d6c593",
  "benchmarks": {
    "encode_large_uniform": {
      "throughput_mbps": 8.5,
      "duration_ms": 235
    },
    "decode_large_uniform": {
      "throughput_mbps": 6.2,
      "duration_ms": 322
    }
  }
}
JSON
```

#### 1.3: Calculate Target Numbers
```
Swift Target = TypeScript * 0.9 (allowing 10% slower)

Example:
TypeScript encode: 8.5 MB/s
Swift target: 7.65 MB/s (90% of TS)

Current Swift: 2.67 MB/s parser
Improvement needed: 2.87x (187% gain)
```

**Deliverable:** `Benchmarks/baseline_typescript.json` + performance gap analysis

---

## Phase 2: Parser Performance Recovery (Days 2-5)

### Goal
Recover -9.3% regression (2.67 → 2.94 MB/s minimum)

### Step 2.1: Profile Parser Hotspots

#### Option A: Instruments (macOS)
```bash
# Build with optimization
swift build -c release

# Profile with Instruments
open -a Instruments
# Select "Time Profiler"
# Target: .build/release/TOONBenchmarks
# Run with parser_micro benchmark
```

Look for:
- Functions consuming >5% time
- Allocation hotspots
- Excessive retain/release

#### Option B: Built-in Performance Tracing
```bash
SWIFTTOON_PERF_TRACE=1 swift run -c release TOONBenchmarks
```

Check output for phase durations:
- Lexing time
- Parsing time  
- Value building time

### Step 2.2: Identify Regression Causes

Review recent commits:
```bash
git log --since="2025-11-01" --oneline -- Sources/TOONCore/Parser.swift | head -20
```

Check for:
- New allocations in hot loops
- Added function calls in `parseValue()`
- Changes to `parseListArray` / `parseTabularRows`
- Token lookahead overhead

### Step 2.3: Optimization Candidates

#### A. Buffer Reuse
**Current:** Parser creates new arrays for each value  
**Optimized:** Reuse buffers for temporary storage

```swift
// Add to Parser struct
private var valueBuffer: [JSONValue] = []
private var stringBuffer: String = ""

// In parseTabularRows
valueBuffer.removeAll(keepingCapacity: true)  // Reuse allocation
```

#### B. Inline Hot Paths
Mark frequently-called functions as `@inlinable`:

```swift
@inlinable
internal func parseValue() throws -> JSONValue {
    // Hot path code
}
```

#### C. Reduce Allocations in parseListArray
```swift
// BEFORE (allocates for each dash check)
if token.kind == .dash { ... }

// AFTER (single check, branch prediction friendly)
guard case .dash = token.kind else { ... }
```

#### D. Token Lookahead Cache
```swift
// Add to Lexer
private var lookaheadCache: Token?

mutating func peek() -> Token {
    if let cached = lookaheadCache {
        return cached
    }
    lookaheadCache = nextToken()
    return lookaheadCache!
}
```

### Step 2.4: Measure Each Change

After each optimization:
```bash
# Benchmark
swift run -c release TOONBenchmarks --format json --output Benchmarks/results/temp.json

# Compare
swift Scripts/compare-benchmarks.swift \
  Benchmarks/results/temp.json \
  Benchmarks/baseline_reference.json \
  --tolerance 0.05

# If improved, commit:
git add ...
git commit -m "perf: reduce parser allocations (+X% throughput)"
```

**Target:** Parser ≥2.94 MB/s (baseline + 10%)  
**Stretch:** Parser ≥3.50 MB/s (above baseline)

---

## Phase 3: Decoder Performance Recovery (Days 6-10)

### Goal
Recover -17.3% regression (3.14 → 3.79 MB/s minimum)

### Step 3.1: Profile Decoder Path

```bash
# Run end-to-end decode benchmark with profiling
instruments -t "Time Profiler" \
  .build/release/TOONBenchmarks \
  decode_end_to_end
```

Determine bottleneck:
- Is it in Parser? (covered by Phase 2)
- Is it in JSONValueDecoder?
- Is it in Codable synthesis?

### Step 3.2: Optimization Candidates

#### A. Container Unwrapping Overhead
```swift
// BEFORE
let container = try decoder.container(keyedBy: Key.self)
let value = try container.decode(String.self, forKey: .field)

// AFTER (cache container reference)
private var cachedContainer: KeyedDecodingContainer<Key>?
```

#### B. CodingKey Lookup Cache
```swift
// Add to JSONValueDecoder.KeyedContainer
private var keyCache: [String: JSONValue] = [:]

func decode<T>(_ type: T.Type, forKey key: Key) throws -> T {
    if let cached = keyCache[key.stringValue] {
        return decode(cached)
    }
    // Lookup and cache
}
```

#### C. Remove Defensive Copies
```swift
// BEFORE
let array = jsonValue.arrayValue ?? []
return Array(array)  // Defensive copy

// AFTER
return jsonValue.arrayValue ?? []  // Direct return
```

#### D. Optimize Number Decoding
```swift
// BEFORE
func decode(_ type: Int.self) throws -> Int {
    guard case .number(let d) = value else { throw ... }
    return Int(d)  // Conversion overhead
}

// AFTER (check bounds once, fast path)
@inlinable
func decode(_ type: Int.self) throws -> Int {
    guard case .number(let d) = value, d.rounded() == d else { throw ... }
    return Int(bitPattern: UInt(bitPattern: d.bitPattern >> 32))  // Unsafe fast path
}
```

**Target:** Decoder ≥3.79 MB/s (baseline + 21%)

---

## Phase 4: Schema-Primed Fast Path (Days 11-15)

### Goal
Demonstrate ≥20% speedup with schema hints vs default analyzer path.

### Step 4.1: Create Schema-Primed Benchmarks

```swift
// In TOONBenchmarks/Benchmarks.swift

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
    let encoder = ToonEncoder()  // No schema - uses analyzer
    measure {
        _ = try! encoder.encode(users)
    }
}
```

### Step 4.2: Optimize Schema Path

#### A. Skip Analyzer When Schema Provided
```swift
// In ToonEncoder
if let schema = self.schema {
    // Direct encode path - no analysis needed
    return try serializeWithSchema(value, schema: schema)
} else {
    // Analyze then serialize
    let analyzed = try analyzer.analyze(value)
    return try serialize(analyzed)
}
```

#### B. Pre-allocate Based on Schema
```swift
func serializeWithSchema(_ value: Encodable, schema: ToonSchema) throws -> String {
    guard case .object(let fields, _) = schema else { ... }
    
    // Pre-allocate string buffer
    var output = ""
    output.reserveCapacity(estimateSize(schema: schema, count: valueCount))
    
    // Direct field serialization (no reflection)
    for field in fields {
        output.append(serializeField(field, schema: field.schema))
    }
}
```

#### C. Direct Field Access
```swift
// BEFORE (analyzer + reflection)
let analyzed = analyzer.analyze(value)  // Runtime analysis
serialize(analyzed)

// AFTER (schema-directed)
for field in schema.fields {
    let value = mirror.children.first { $0.label == field.name }?.value
    serializeValue(value, schema: field.schema)  // Type known at compile time
}
```

### Step 4.3: Measure Schema Gain

```bash
swift run -c release TOONBenchmarks --format json | jq '
  .benchmarks |
  {
    "default_encode": .default_encode_throughput,
    "schema_encode": .schema_encode_throughput,
    "gain_percent": ((.schema_encode_throughput - .default_encode_throughput) / .default_encode_throughput * 100)
  }
'
```

**Target:** Schema-primed ≥20% faster than default

---

## Phase 5: Documentation & Release (Days 16-18)

### Step 5.1: Update Performance Tracking

```bash
# Update docs/plans/performance-tracking.md
git log --grep="perf:" --since="2025-11-16" --oneline

# Document each optimization:
# - Before/after MB/s
# - Technique used
# - Code references
```

### Step 5.2: Update Benchmarks Baseline

```bash
# New baseline after optimizations
swift run -c release TOONBenchmarks --format json --output Benchmarks/baseline_reference.json

git add Benchmarks/baseline_reference.json
git commit -m "perf: update baseline after Stage 11 optimizations

Parser:  2.67 → 3.X MB/s (+Y%)
Decoder: 3.14 → 3.X MB/s (+Y%)
Schema:  N/A → X MB/s (Z% vs default)

All within ±10% of TypeScript reference."
```

### Step 5.3: Update README Badges

```markdown
[![Performance](https://img.shields.io/badge/Performance-±10%25%20TypeScript-success)](https://joelklabo.github.io/SwiftTOON/perf/)
```

### Step 5.4: Release v0.2.0 (Performance Release)

```bash
# Update CHANGELOG.md
# Tag release
git tag v0.2.0
git push origin v0.2.0

# Create GitHub release
gh release create v0.2.0 \
  --title "v0.2.0 - Performance Optimization Release" \
  --notes "Stage 11 complete: ±10% TypeScript parity achieved"
```

---

## Success Criteria

- [ ] Parser within ±10% of TypeScript
- [ ] Decoder within ±10% of TypeScript  
- [ ] Schema-primed ≥20% faster than default
- [ ] All benchmarks passing with new baselines
- [ ] Performance tracking document updated
- [ ] v0.2.0 released

---

## Tools & Commands Reference

### Profiling
```bash
# Instruments (macOS)
instruments -t "Time Profiler" .build/release/TOONBenchmarks

# Built-in tracing
SWIFTTOON_PERF_TRACE=1 swift run -c release TOONBenchmarks

# Allocations
instruments -t "Allocations" .build/release/TOONBenchmarks
```

### Benchmarking
```bash
# Run benchmarks
swift run -c release TOONBenchmarks --format json --output results.json

# Compare
swift Scripts/compare-benchmarks.swift results.json baseline.json --tolerance 0.10

# Watch performance
watch -n 60 'swift run -c release TOONBenchmarks | grep MB/s'
```

### Quick Checks
```bash
# Build optimized
swift build -c release -Xswiftc -enforce-exclusivity=checked

# Size check
ls -lh .build/release/*.xctest

# Assembly inspection (check inlining)
swift build -c release -Xswiftc -S
```

---

## Risk Mitigation

### Risk 1: Optimization Breaks Tests
**Mitigation:** Run full test suite after each optimization
```bash
swift test --enable-code-coverage --parallel
```

### Risk 2: Premature Optimization
**Mitigation:** Profile first, optimize only proven hotspots

### Risk 3: Regression in Coverage
**Mitigation:** Coverage must stay ≥95% during optimization

### Risk 4: Platform-Specific Optimization
**Mitigation:** Test on both macOS and Linux (via CI)

---

**Next Action:** Start Phase 1 - Benchmark TypeScript reference CLI

Ready to execute! 🚀
