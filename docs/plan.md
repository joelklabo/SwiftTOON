# SwiftTOON Implementation Plan (TDD-First)

## Targets & Goals

- **TOONCore** – dependency-free lexer, parser, serializer, error taxonomy, plus a `JSONValue` enum for intermediate representations.
- **TOONCodable** – bridges to Swift’s `Encoder`/`Decoder`, `Data` helpers, JSON round-tripping utilities, and schema-primed fast paths.
- **TOONCLI** – executable (`toon-swift`) for encode/decode/validate/stats operations, consuming the same APIs as external users.
- **TOONBenchmarks** – benchmark + fuzz harness compiled into a testable module to keep micro/macro perf tests in CI from day one.
- Goals: strict TOON v2 compliance, zero third-party deps, ≥99% line + branch coverage (unit/integration/perf), throughput within 10% of reference TypeScript implementation, and byte-for-byte parity on all official fixtures.

## Stage 0 – Inputs & Guardrails

1. **Clone & pin reference artifacts**
   - Keep `toon-format/toon` under `reference/` and add git submodule or script to pull tagged releases.
   - Extract all spec fixtures, fuzz seeds, and benchmark datasets into `Tests/Fixtures` via a generator script.
   - Tests-first: snapshot counts/hashes of fixture files; CI fails if upstream diverges without regenerating.
2. **Fixture generator tooling**
   - Write `Scripts/update-fixtures.swift` that copies `.toon/.json/.md` files from `reference/` into `Tests/Fixtures`, canonicalizes line endings, and emits a manifest (JSON) with file hashes & spec version.
   - Add XCT test asserting manifest exists and matches repository state; fails if fixtures are out of sync or script hasn’t been run.
3. **Reference CLI bridge**
   - Create a Swift test helper that shells out to `pnpm toon encode/decode`.
   - Add a failing XCT test asserting the helper can round-trip a known fixture via the TS CLI before any Swift code exists; this guards the harness itself.
4. **Perf baseline harness**
   - Scaffold `TOONBenchmarks` target with placeholder benchmarks that currently call the reference CLI to produce baseline JSON/TOON throughput numbers.
   - Store baseline artifacts (JSON of ops/sec) so we can compare as soon as Swift encoder/decoder exists.
5. **Coverage + badge plumbing**
   - Configure Codecov token/permissions and add a stub `.codecov.yml` enforcing ≥99/97 thresholds once data exists.
   - Create TODO tests that fail until SwiftPM targets produce coverage files, ensuring CI badge wiring is validated early.

## Stage 1 – Workspace Scaffolding (Red → Green → Refactor Cycle)

1. `swift package init --type library` → add targets `TOONCore`, `TOONCodable`, `TOONCLI`, `TOONBenchmarks`.
2. Add empty public APIs (protocol stubs, structs) plus compiler-prohibiting tests (e.g., `XCTExpectFailure("Not implemented")`) so CI red-lights until functionality ships.
3. Wire SwiftPM test fixture resources + `reference` script invocation so tests can load `.json` + `.toon` pairs immediately.
4. Add DocC bundle + README skeleton referencing coworker goals, ensuring doc tests fail until filled later (keeps doc coverage aligned).
5. Introduce baseline `CHANGELOG.md`, `CONTRIBUTING.md`, and templated release notes referencing spec version; tests ensure these files mention latest planned milestone.
6. Add placeholder CLI integration test invoking `swift run toon-swift --help`, marked `XCTExpectFailure` until CLI target exists to verify harness structure.

## Stage 2 – Lexer (TDD)

1. **Tests first**
   - Write exhaustive lexer tests covering identifiers, dotted keys, numbers, quoted strings, escape sequences, indentation computations, delimiter tokens, and newline/EOF handling.
   - Include fuzz-style property tests (seeded) that generate random whitespace + delimiters to ensure token stream invariants (monotonic offsets, non-overlapping ranges).
2. **Implement**
   - Build an `UnsafeRawBufferPointer`-driven scanner with minimal allocations, flagged `@usableFromInline`.
3. **Perf tests**
   - Add benchmark measuring MB/s on fixture files; store numbers in JSON for regression tracking (fail test if >5% slower vs previous commit once stable).

## Stage 3 – Parser & Error Taxonomy

1. **Tests first**
   - Describe indentation stack behaviors via table-driven tests (increase, flat, decrease, invalid dedent).
   - For tabular arrays, add tests validating row counts, delimiter enforcement, schema mismatch, and dotted-key folding.
   - For list arrays, add fixtures mirroring `arrays-nested` (dash entries, nested arrays, inline `[N]:` definitions, empty items).
   - Error taxonomy tests: each spec-defined failure must map to a specific `TOONError` case with line/column context.
2. **Implement**
   - Context-aware recursive-descent parser that tracks object/array stacks, producing JSONValue trees while enforcing indentation rules for tabular + list arrays.
3. **Differential tests**
   - Run `arrays-tabular` + `arrays-nested` fixtures through parser → JSONValue and compare with reference CLI JSON output; expand to the rest of the spec fixtures once decoder integration lands.
4. **Perf**
   - Bench parse throughput + memory allocations; fail perf test if allocations increase >X% (using `swift test --filter PerfParser` with `MallocStackLogging`).

## Stage 4 – Decoder Integration (JSON Builders + Codable Streaming)

1. **Tests first**
   - Build XCTests that decode parser outputs (`JSONValue`) into `Foundation` representations and directly into sample `Decodable` structs using `TOONDecoder`.
   - Use spec fixtures (`arrays-tabular`, `arrays-nested`, `objects`, `primitives`, `delimiters`, etc.) as inputs to ensure coverage across structural classes.
   - Add streaming tests: supply a huge TOON file via custom `InputStream`, ensure constant memory.
2. **Implement**
   - Provide two APIs: `TOONDecoder.decode<T: Decodable>(_ type: T.Type, from data: Data)` layered on top of the parser, and low-level streaming callbacks for incremental consumers.
3. **Differential**
   - Use reference CLI to decode the same fixtures and assert structural equality + identical numeric precision, storing fixture pairs for regression.
4. **Perf**
   - Add round-trip decode benchmarks vs `JSONDecoder` (same dataset) to ensure we track parity, including large arrays and deeply nested objects.

## Stage 5 – Encoder (Structure Analyzer → Serializer)

1. **Tests first**
   - JSON fixture to TOON golden tests (expected `.toon` output).
   - Eligibility analyzer tests: feed arrays w/ uniform/mixed data and assert analyzer decisions (tabular vs nested).
   - Quoting matrix tests ensuring all special-case strings produce required quoting.
2. **Implement**
   - Analyzer enumerates objects to confirm uniform schema; serializer writes via `UnsafeMutableBufferPointer`.
   - Provide options for delimiter choice, indent width, leniency.
3. **Differential**
   - Run JSON fixtures through Swift encoder + TS CLI encoder; outputs must match exactly (or differences documented via allowlist).
4. **Perf**
   - Bench encode throughput vs TypeScript CLI and vs `JSONEncoder` for same structures.

## Stage 6 – Codable Bridges & Schema-Primed Fast Path

1. **Tests first**
   - Codable round-trip tests using structs/enums with nested arrays.
   - Schema priming tests: supply declared schema, mutate inputs to ensure fast path rejects mismatches deterministically.
2. **Implement**
   - Custom `Encoder`/`Decoder` classes, `ToonSchema` description, optional partial evaluation for fixed layouts.
3. **Perf**
   - Compare schema-primed path vs default to ensure measurable gains; make perf tests part of nightly CI.

## Stage 7 – CLI & UX

1. **Tests first**
   - Integration tests invoking `toon-swift encode/decode --stats`, checking exit codes, stdout/stderr, file outputs.
   - Snapshot tests for `--validate`, `--delimiter`, `--lenient`.
2. **Implement**
   - CLI built with `ArgumentParser` (if acceptable) or manual parsing to stay dependency-free.
   - Provide piping support (stdin/stdout) and helpful diagnostics using shared error taxonomy.
3. **Perf/Smoke**
   - CLI bench command wraps existing benchmarks; ensures shipping binary can run perf tests locally.

## Stage 8 – Testing Depth & Automation

1. **Golden & round-trip suites**
   - Encode → decode every fixture, assert equality with canonical JSON/TOON.
   - Random JSON generator fuzz tests feeding both Swift + TypeScript encoders (differential).
2. **Coverage gates**
   - CI runs `swift test --enable-code-coverage`; fail if <99% line or <97% branch for TOONCore/TOONCodable.
3. **Sanitizers & fuzzing**
   - Address/Thread sanitizers in CI; nightly libFuzzer job generating TOON lexemes, comparing behaviors with reference CLI.
4. **Performance regression guard & telemetry**
   - Bench harness emits structured JSON (`suite`, `dataset`, `metric`, `value`, `unit`, `commit`, `runner`). Baseline data lives in `Benchmarks/baseline_reference.json`.
   - `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` + `Scripts/compare-benchmarks.swift` enforce ≤5% regressions inside CI (`.github/workflows/perf.yml`).
   - Separate GitHub Action (see [`docs/performance-tracking.md`](performance-tracking.md)) will append results to `Benchmarks/history.json`, publish Shields endpoint payload + PNG chart to `gh-pages/perf/`, and refresh the README badge/graph so performance trends are always visible.

## Stage 9 – Documentation & Release Readiness

1. **DocC & README**
   - Doc tests referencing real APIs must compile (TDD: failing doc tests until APIs exist).
2. **Spec alignment report**
   - Auto-generate table summarizing spec clauses + test names proving coverage; diff checked in CI.
3. **Packaging**
   - Provide `Package.resolved`, changelog, semantic versioning, and sample `Package.swift` snippet for consumers.

## Success Criteria

- 100% of official fixtures + differential tests pass on both encode and decode.
- Continuous benchmark suite shows Swift implementation within ±10% of TypeScript throughput; schema-primed path demonstrates ≥20% gain on eligible datasets.
- Test coverage thresholds met (line ≥99%, branch ≥97%) with all code paths exercised via automated tests from day one.
- CLI + library share identical code paths, ensuring end-to-end parity and reproducible performance metrics.
