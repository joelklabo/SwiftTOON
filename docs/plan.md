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
   - Replace the Codecov dependency with an in-repo workflow:
     - Swift script produces a Shields payload + history JSON by running `llvm-cov export -summary-only` over `.xctest` binaries and the `.build/debug/codecov/default.profdata` profile.
     - `coverage.yml` workflow (push to `main`) runs tests with `--enable-code-coverage`, generates artifacts, and publishes to `gh-pages/coverage/` using `peaceiris/actions-gh-pages@v3`.
   - README badge must point at `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-badge.json`.
  - Document the manual/local workflow in `docs/agents.md` + `docs/plan.md#performance-tracking-playbook` so every change keeps coverage + perf telemetry in sync.

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
4. **Implementation plan**
   - Use the Stage 3 Parser Checklist below to keep every refactor tied to failing tests, error messages, and lenient-mode behaviors.
5. **Perf**
   - Bench parse throughput + memory allocations; fail perf test if allocations increase >X% (using `swift test --filter PerfParser` with `MallocStackLogging`).

> **Status:** Lenient list arrays (padding/truncation), indentation fixtures, and tabular/list error coverage are implemented; the parser now matches the Stage 3 checklist. Next, follow the Stage 4 decoder plan (streaming + schema priming) to build the higher-level API.

### Stage 3 Parser Checklist

#### Goals
- Enforce tabular and list array semantics (length tokens, headers, delimiting rows).
- Report the new `ParserError` cases with accurate line/column metadata.
- Support lenient array decoding when requested (`Parser.Options(lenientArrays: true)`).

#### Checklist
1. **Tabular rows**
   - Ensure `parseTabularRows` reads exactly `length` rows, validates header counts, and emits `ParserError.tabularRowFieldMismatch` when rows vary (with actual/expected values).
   - Track the indent/dedent transitions after the tabular block so nested objects resume at the right level.
2. **List arrays**
   - Tighten `parseListArray` to accept one dash per item, enforce `- value` vs `- [N]` sequences, and reject stray `-` tokens while reporting `ParserError.unexpectedToken` when necessary.
   - Allow lenient padding/truncation when `options.lenientArrays == true`.
3. **Inline arrays**
   - Confirm `parseArrayValue` handles inline `[length]: value1,value2` declarations by counting delimiters, ensuring no additional newlines slip in, and failing with `ParserError.inlineArrayLengthMismatch` when counts differ (unless lenient).
4. **Error taxonomy**
   - Add helper methods to build `ParserError` messages with line/column data (reuse tokens’ `line/column`).
   - Cover missing columns, unexpected dedents/indents, and unmatched `:`/`[` tokens with precise error strings used by the tests.
5. **Lenient mode**
   - When lenient arrays are enabled, allow rows with fewer/more columns by padding/truncating to `length`, but still emit warnings in the tests via `ParserError` (if desired).
6. **Validation & regression testing**
   - After each change, run `swift test --filter TOONCoreTests` plus `swift test --filter TOONCodableTests` to verify new parser behavior remains consistent.

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

### Stage 4 Decoder/Encoder Checklist

#### Goals
- Stream TOON data without data races via streaming `InputStream` decoder callbacks.
- Schema-primed encode/decode paths that fail fast when payloads deviate from explicit `ToonSchema`s.
- Fixture round-trips that confirm encode → decode and decode → encode produce consistent TOON using schema hints.

#### Checklist
1. **Streaming decoder callback**
   - Extend `DecoderFixtureTests` with larger chunked payloads and ensure `ToonDecoder.streamJSONValue` invokes the callback exactly once, even when the stream is chunked.
   - Add tests comparing stream vs data decoding results.
2. **Schema-primed emitter**
   - Expand `ToonSchemaIntegrationTests` (already added) with fixture coverage from `Tests/ConformanceTests/Fixtures/encode/representation-manifest.json`.
   - Ensure `ToonEncoder` rejects extra fields when schema disallows them and `ToonDecoder` rejects unexpected fields when parsing with the same schema.
3. **Fixture round-trips**
   - Add encode → decode tests for at least the `arrays-tabular`, `arrays-nested`, and `delimiters` fixtures, verifying structural equality after the round trip and referencing analyzer manifest decisions.
4. **Performance/perf instrumentation**
   - Capture analyzer manifest entries (`CaptureEncodeRepresentations`) during fixture runs so each encode path can be traced.

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
5. **Artifact publishing**
   - Run `swift run CaptureEncodeRepresentations` to persist `representation-manifest.json` so analyzer format decisions accompany every encode fixture.
   - After benchmarks + `Scripts/update-perf-artifacts.swift`, publish `perf-artifacts/` to `gh-pages/perf/` so the badge/stacked-area graph automatically reflect each run.

> **Status:** `ToonAnalyzer` tests now cover inline/tabular/list heuristics plus schema hints, aligning the analyzer/serializer expectations with Stage 5’s requirements. The serializer’s encode fixtures already round-trip, so the next focus is Stage 6’s Codable bridges and schema priming fast paths.

> **Status:** Encode fixture harness is live and all upstream golden tests now run the Swift serializer with delimiter/indent/key folding options. `ToonSerializer` handles inline/tabular/list arrays, preserves field order via `JSONObject`, emits deterministic quoting/number formatting, and enforces safe key folding (collision/quoting/flattenDepth). Next up: wire the differential comparison against the reference TypeScript encoder and add encode-side benchmarks before declaring Stage 5 complete.

## Stage 6 – Codable Bridges & Schema-Primed Fast Path

1. **Tests first**
   - Codable round-trip tests using structs/enums with nested arrays.
   - Schema priming tests: supply declared schema, mutate inputs to ensure fast path rejects mismatches deterministically.
2. **Implement**
   - Custom `Encoder`/`Decoder` classes, `ToonSchema` description, optional partial evaluation for fixed layouts.
3. **Perf**
   - Compare schema-primed path vs default to ensure measurable gains; make perf tests part of nightly CI.

> **Status:** Schema priming is implemented and ToonEncoder/ToonDecoder now rely on custom JSONValue coders (no `JSONSerialization` hop). Codable round-trip tests exercise the new encoder/decoder and the new schema-aware regression suites ensure tabular hints and nested-arrays mismatches are handled deterministically. Future perf work will compare schema-primed vs default paths.

### Benchmarks Checklist

1. **Bench fixtures**
   - Ensure `Benchmarks/Datasets/large.toon` and `users.toon` exercise practical lexer/parser workloads.
2. **Throughput suites**
   - `TOONBenchmarks` should run `lexer_micro`, `parser_micro`, and `decode_end_to_end` over the datasets and emit JSON (see `Benchmarks/results/latest.json`).
3. **CLI integration**
   - `toon-swift bench` should wrap the benchmark suite and write JSON as well.
4. **Artifacts**
   - Run `Scripts/update-perf-artifacts.swift` (or `Scripts/run-benchmarks.swift`) to produce `Benchmarks/perf-artifacts/{perf-history.json, perf-badge.json, perf-history.png, meta.json}`.
5. **Docs**
   - Document the benchmark command/outputs in `README.md`/`docs/performance-tracking.md` and point to the artifacts.

## Stage 7 – CLI & UX

1. **Tests first**
   - Integration tests invoking `toon-swift encode/decode --stats`, checking exit codes, stdout/stderr, file outputs (initial focus on encode/decode parity and `--stats` JSON summary).
   - Snapshot tests for `--validate`, `--delimiter`, `--lenient` (deferred until after base CLI subcommands exist).
2. **Implement**
   - CLI built with `ArgumentParser` (if acceptable) or manual parsing to stay dependency-free.
   - Provide piping support (stdin/stdout) and helpful diagnostics using shared error taxonomy.
3. **Perf/Smoke**
   - CLI bench command wraps existing benchmarks; ensures shipping binary can run perf tests locally.

> **Status:** Encode/decode/stats/validate support STDIN/STDOUT, delimiter + indent flags, lenient decoding, and the new `bench` command that wraps `TOONBenchmarks`. Integration tests cover file + streaming flows as well as tab delimiters, lenient parsing, bench JSON output, and validate failure paths. We added a help-output snapshot; future follow-ups can extend snapshots to additional diagnostics as the CLI grows.

### CLI & UX Checklist

#### Goals
- Provide encode/decode/validate/stats/bench commands mirroring the reference CLI with piping support and delimiter/indent/lenient options.
- Keep CLI snapshots/tests guarding help output, stats JSON, and streaming behaviors.
- Integrate benchmarks into the CLI and capture manifest/perf outputs for release notes.

#### Test-first checklist
1. **Command coverage**
   - Write tests that run `toon-swift encode`/`decode`/`stats`/`validate` against fixture files and STDIN/STDOUT streams; verify exit codes and outputs match expectations.
   - Add a snapshot test for `toon-swift --help` to avoid regressions.
2. **Stats JSON**
   - Ensure `stats` writes JSON with bytes, reduction percent, and optionally delimiter/indent info; add fixture tests verifying the JSON shape.
3. **Lenient/strict flags**
   - Confirm `--lenient` vs `--strict` toggles parser behavior, producing success/failure as expected when hitting delimiter anomalies.
4. **Bench command**
   - Add `toon-swift bench` subcommand wrapping `TOONBenchmarks`, allowing format/output options and verifying it produces JSON or CSV output.
5. **Documentation & release**
   - Keep README CLI usage, release checklist, and DocC tutorials synchronized with the commands and sample outputs.

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
   - Separate GitHub Action (see the [Performance Tracking Playbook](docs/plan.md#performance-tracking-playbook)) will append results to `Benchmarks/history.json`, publish Shields endpoint payload + PNG chart to `gh-pages/perf/`, and refresh the README badge/graph so performance trends are always visible.

> **Status:** Deterministic fixtures now round-trip through the Swift encoder/decoder and random JSON differential tests compare our serializer against the TypeScript CLI. CI currently enforces ≥85% coverage for `Sources/TOONCore` and ≥78% for `Sources/TOONCodable` (thresholds will ratchet toward the 99% goal as we add more exhaustive parser/codec tests); the coverage checker filters real `.xctest` binaries (ignoring `.dSYM` payloads) and streams a single `llvm-cov export` pass per run so Actions no longer deadlocks on large JSON payloads. The `JSONValueEncoder`/`JSONValueDecoder` matrix, dedicated `JSONObject`/`JSONTextParser` suites, and the Darwin-only TOON lexeme fuzzer (now emitting inline, dash, and tabular forms cross-checked against the TypeScript CLI when supported) cover scalar conversions, nested containers, unicode escapes, and parser leniency branches. Dedicated sanitizer jobs run AddressSanitizer + ThreadSanitizer on macOS, the new malformed lexeme fuzz suite (tabs-in-indent, unterminated strings, zero-length array declarations with values) now guards the decoder from invalid lexemes, and the encode fixture harness once again executes the `arrays-objects` + `key-folding` suites (boosting `ToonSerializer` coverage into the high 90s). `Sources/TOONCore`/`Sources/TOONCodable` now sit around 91%/91% line coverage locally, but we'll keep the CI gate at 85/78 until the remaining JSONValueDecoder/ToonSchema paths are under test. (Random differential CLI comparisons are temporarily skipped behind `ENABLE_REFERENCE_DIFF=1` while we investigate upstream parity.)

## Stage 9 – Documentation & Release Readiness

> **Status:** Stage 9 is complete (2025-11-16). DocC tutorials verified, spec alignment checker passing, spec version documented (v2.0.0 / commit 3d6c593), CHANGELOG/README updated with v0.1.2 release notes. Ready to tag release.

1. **DocC & README**
   - Doc tests referencing real APIs must compile (TDD: failing doc tests until APIs exist).
   - Ship DocC tutorials (“Getting started”, “Tabular arrays”, “Schema priming”) containing real snippets so the exported Bundle remains runnable and exercises every public API.
   - Mirror README Quick Start + CLI usage sections with DocC excerpts, keeping the snapshots/tests aligned with the living CLI behavior.
2. **Spec alignment report**
   - Auto-generate table summarizing spec clauses + test names proving coverage; diff checked in CI.
   - Every spec clause entry must cite the canonical fixture/test pair and the reference version (recorded in `docs/spec-version.md` or similar) so reviewers can verify compliance quickly.
   - Draft `docs/spec-alignment.md` with columns for `<Clause>`, `<Description>`, `<Tests>`, `<Fixture>` & `<Reference SHA>`, and keep it synced with `reference/spec/manifest.json`.
3. **Packaging**
   - Provide `Package.resolved`, changelog, semantic versioning, and sample `Package.swift` snippet for consumers.
   - Draft release notes following “Keep a Changelog”, note the TOON spec tag used, and add a new “Releases” section in the README pointing to the latest `CHANGELOG.md` entry.
   - Ensure `Package.swift`’s `swift-tools-version` plus platform matrix match the README/platform badge details before tagging.
4. **Release wrap-up**
   - Update `docs/DocCTutorials.md` with the DocC tutorial checklist once the stories ship, and confirm each tutorial passes DocC validation.
   - Refresh `README.md` to describe the new badges/history graph plus perf/coverage workflow.
   - Run `Scripts/check-spec-alignment.swift` and publish the updated clause table along with the release tag.
   - Run `Scripts/release-checklist.sh` as the final gating step before tagging plus `gh release create …` (or similar).

### Release Plan Checklist

#### Goals
- Verify Stage 1–6 regression suites plus DocC builds pass.
- Ensure perf/coverage artifacts are updated and uploaded via release workflows.
- Publish release notes, update the README “Releases” section, and run `gh release create`.

#### Checklist
1. Run `swift test --enable-code-coverage --parallel`, `docc convert`, and `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` plus `swift Scripts/compare-benchmarks.swift`.
2. Regenerate `docs/spec-alignment.md`/`docs/spec-version.md` if the spec changed, and rerun `Scripts/check-spec-alignment.swift`.
3. Update `CHANGELOG.md` (Keep a Changelog style) with release highlights (stages completed, spec pin, perf badges) and link it from README `Releases`.
4. Use `gh release create <tag>` (or `gh-commit-watch` wrapper) to publish the binaries + coverage/perf artifacts and ensure CI/perf workflows succeeded.

### DocC tutorial plan
- **Getting started** – Outline the quickstart path (install, encode/decode, CLI usage) and include failing tests referencing the actual APIs so the doc builds fail until the functions exist.
- **Tabular arrays** – Demonstrate how encoder/decoder interpret uniform arrays, show the analyzer decision path, cite relevant tests (`Tests/TOONCodableTests/ToonArrayAnalyzerTests.swift`), and include the CLI `encode` command capturing a fixture sample.
- **Schema priming** – Walk through constructing `ToonSchema`, primed `ToonEncoder/Decoder`, and show the performance benefit (link to benchmark results). Use DocC code snippets that compile against `Sources/TOONCodable`.
- Keep a `docs/DocCTutorials.md` checklist summarizing each DocC tutorial plus expected tests; update it whenever the API surface changes so the failing doc tests remain aligned with the plan.
- Refer to `docs/DocCTutorials.md` whenever a tutorial ships so the plan, DocC bundle, and README stay synchronized.

- Create `docs/spec-version.md` capturing upstream TOON spec tag/commit used for this milestone; update it whenever `reference/` is rebased.
- Link `docs/spec-alignment.md` and `docs/spec-version.md` from `README`’s Spec section so reviewers can find the clause-to-test mapping without digging through history.
- Prevent spec-alignment drift by running `swift Scripts/check-spec-alignment.swift` (calls out required clause rows); the CI pipeline now executes it so coverage is automated while the manifest gate is still pending.

### Packaging readiness
- Keep `Package.resolved` committed and review it when dependencies change.
- Before each release, regenerate `CHANGELOG.md` entry referencing the spec version and highlight performance/coverage improvements.
- Add `Releases` section to the README containing a summary line for each published release (version, spec tag, date, perf status).
## Performance Tracking Playbook

Purpose: capture and publish SwiftTOON performance metrics from day one so regressions are caught automatically and visitors see trends directly on the GitHub page (badge + graph).

### Step-by-Step Execution

1. **Step 1 – Author Benchmarks & Fixtures**
   - Create canonical datasets under `Benchmarks/Datasets/` (large lexer/parser stress files, representative JSON/TOON pairs) plus `datasets-manifest.json` with SHA256 hashes.
   - Implement benchmark cases in `TOONBenchmarks` (`lexer_micro`, `parser_micro`, `decode_end_to_end`, `encode_end_to_end`, `cli_round_trip`).
   - Add CLI flags so every run can emit JSON: `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`.
2. **Step 2 – Persist Baselines & Local Guard**
   - Capture original measurements in `Benchmarks/baseline_reference.json` (JSON wrapper containing `generatedAt` + `samples`).
   - Add `Scripts/compare-benchmarks.swift` (run via `swift Scripts/compare-benchmarks.swift latest baseline --tolerance 0.05`) to diff new results vs. the committed baseline.
   - Store ad-hoc benchmark runs in `Benchmarks/results/latest.json` (ignored by Git) so contributors can repeat the workflow without polluting commits.
   - Document the local workflow (benchmark command + compare script) plus the analyzer manifest capture (`swift run CaptureEncodeRepresentations`) in this file, `README.md`, and `docs/agents.md`.
3. **Step 3 – CI Regression Gate**
   - `perf.yml` workflow runs on macOS 14 for every push/PR touching perf-sensitive paths (and is manually runnable).
   - Steps inside the workflow:
     - Checkout repo.
     - `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
     - `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.2`
     - Upload the JSON artifact for debugging.
   - The workflow fails the build if any benchmark deviates beyond tolerance or if samples are missing, giving immediate regression feedback.
4. **Step 4 – History & Visualization Pipeline**
   - `perf-history.yml` (trigger: push to `main` + manual dispatch) reruns the suite, compares against the baseline (tolerance currently 20% on CI runners), and then uses `Scripts/update-perf-artifacts.swift` to append `{commit, timestamp, samples}` to a history file.
   - Artifacts written to `perf-artifacts/`:
     - `perf-history.json` – the entire history (metadata + entries).
     - `perf-badge.json` – Shields endpoint payload (decode throughput MB/s).
     - `perf-history.png` – QuickChart-generated line chart of decode throughput over time.
     - `meta.json` – repo/branch metadata for debugging.
   - `peaceiris/actions-gh-pages` publishes the artifacts to `gh-pages/perf/`, making them available via:
     - Badge – `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-badge.json`
     - Graph – `https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-history.png`
5. **Step 5 – Surface Data on GitHub**
   - Replace the temporary badge in `README.md` with the live Shields endpoint once Step 4 lands.
   - Embed the PNG graph (served from `gh-pages`) inside the README’s “Performance Tracking” section so visitors immediately see throughput trends.
   - Optionally publish an extended view on GitHub Pages (`docs/perf/index.md`) that consumes `perf-history.json` for interactive charts.
6. **Step 6 – Commit & Plan Hygiene**
   - Tackle each step above via focused commits/PRs with descriptive messages (e.g., `perf: add benchmark datasets`, `perf: add compare script`).
   - Update this plan, `docs/plan.md`, `README.md`, and `docs/agents.md` after every milestone so contributors always see the latest workflow.

### Coverage Telemetry (Codecov Replacement)

#### Goal
Surface real SwiftPM coverage numbers without any third-party SaaS dependency so badges stay accurate even if Codecov tokens are missing. Reuse the same gh-pages approach that already powers the performance badge/graph.

#### Plan
1. **Local generation**
   - Always run `swift test --enable-code-coverage --parallel`.
   - Execute `swift Scripts/coverage-badge.swift --profile .build/debug/codecov/default.profdata --binary-root .build --output coverage-artifacts` which:
     - Locates every `.xctest/Contents/MacOS/*` binary under `.build`.
     - Calls `llvm-cov export -summary-only …` to grab totals directly from LLVM tooling (no JSON parsing hacks).
     - Emits:
       - `coverage-badge.json` – Shields payload with percent + label + color.
       - `coverage-summary.json` – Structured data `{lines, regions, functions, timestamp, commit}` for history.
       - `README-snippet.md` – Optional snippet that can be embedded elsewhere if we ever want textual coverage notes.
2. **CI workflow**
   - New workflow `.github/workflows/coverage.yml` (trigger: push to `main`, manual dispatch) that runs the same local steps plus writes metadata (commit SHA, branch, git time).
   - Publish artifacts to `gh-pages/coverage/` via `peaceiris/actions-gh-pages@v3` with `force_orphan: true` (parallel to `perf-history.yml`).
   - Store latest badge JSON at `https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-badge.json`.
3. **README badge**
   - Replace the Codecov badge with `https://img.shields.io/endpoint?url=<gh-pages-url>` once the workflow lands.
   - Add a short paragraph in the README “Coverage & Quality” section describing how the badge is produced (LLVM summary + gh-pages).
4. **Agent docs**
   - `docs/agents.md` + root `AGENTS.md` must describe:
     - How to run the coverage script locally.
     - When to re-run the gh-pages workflow (every push to `main` automatically plus manual dispatch if badge stalls).
     - Expectation that contributors check `gh run list` / `gh-commit-watch` for `coverage` runs in addition to `ci`, `Performance Benchmarks`, and `Publish Performance History`.

#### Future Enhancements
- Track historical coverage trends (store `coverage-history.json` alongside the badge and render a sparkline similar to perf).
- Emit per-target coverage so we can spot regressions isolated to `TOONCore` vs `TOONCLI`.
- Gate merges on minimum coverage thresholds once data stabilizes (e.g., fail CI if `<99%` line coverage).

### Local Developer Checklist
1. `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
2. `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
3. (Optional) `swift run Scripts/visualize-benchmarks Benchmarks/results/dev.json` to render a local sparkline (future enhancement).

### Additional Future Enhancements
- Track memory/allocations alongside throughput.
- Warm benchmarks (discard first run) for stability.
- Add Linux runners for cross-platform data.
- Publish percentile stats (p50/p95) for CLI round-trips.
- Build an interactive GitHub Pages dashboard that consumes `gh-pages/perf/perf-history.json`.
- Mirror the coverage badge plan for mutation testing or fuzzing depth once those harnesses exist.

## Stage 8 – Performance Iteration Program

This plan tracks the ongoing performance improvement loop after the release. Follow it each sprint so the perf history graph keeps trending upward and the badge reflects each MB/s gain.

### Objectives
1. **Measure current hotspots** – Collect telemetry for the lexer, parser, decoder, and serializer using the instrumented tracker (`SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks …`).
2. **Profile the hot paths** – Record a Time Profiler + Allocations trace (when Instruments is available) or rely on the signposted tracker output, so you know which parser path to optimize next.
3. **Optimize incrementally** – Apply focused fixes (buffer reuse, inline parsing, allocation reduction) and guard them with the benchmark harness to prevent regressions.
4. **Refresh artifacts** – Rerun `TOONBenchmarks --format json --output Benchmarks/results/latest.json`, compare via `swift Scripts/compare-benchmarks.swift … --tolerance 0.05`, and generate new `Benchmarks/perf-artifacts/*` via `swift Scripts/update-perf-artifacts.swift …`.
5. **Document & release** – Update `docs/performance-tracking.md` (iteration log template) with the goal, profiler output, and bench delta; if the change affects release artifacts, rerun `Scripts/release-checklist.sh`.

### Worklog Template
Every perf iteration should produce:
1. **Profiling evidence** – note the Instruments trace or tracker output that drove the change.
2. **Benchmarks** – rerun `swift run TOONBenchmarks …` and the compare script to confirm the throughput delta.
3. **Artifacts** – regenerate `Benchmarks/perf-artifacts/*` so the badge/graph plot the new MB/s.
4. **Doc update** – add an entry to `docs/performance-tracking.md` describing the goal, optimization, and measured delta.
5. **Commit & badge** – commit the change plus the refreshed artifacts so the git history shows continuous perf progress.

### Tools
- **Xcode Instruments** (Time Profiler, Allocations) targeting the `decode_end_to_end` or `parser_micro` suites when available.
- **SWIFTTOON_PERF_TRACE** + `ParserPerformanceTracker` for CLI-accessible timing when Instruments isn’t an option.
- **Scripts/run-benchmarks.swift** + `Scripts/update-perf-artifacts.swift` to regenerate baseline JSONs, badges, and perf graphs.
- **QuickChart** (via `Scripts/update-perf-artifacts.swift`) to refresh the PNG chart that the README embeds.

### Next Actions
1. Run `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` (with `SWIFTTOON_PERF_TRACE=1` for tracer output) to capture the current baseline.
2. Profile the hottest parser path (maybe `parseListArray`, `buildValue`, or `parseInlineValue`) via Instruments or the tracker output.
3. Apply the targeted optimization, rerun the benchmark + compare + artifact workflows, and update `docs/performance-tracking.md`.
4. Commit + push the change plus the refreshed artifacts so the perf graph and badge update accordingly.

> **Status:** Stage 8 is complete. The parser now reserves `JSONObject` buffers, benchmarks publish `phase|…|duration` samples, and `Scripts/update-perf-artifacts.swift` renders both throughput and per-phase lines so the README graph surfaces each translation stage. The per-stage instrumentation lives alongside the usual MB/s numbers.

Repeat this cycle so every MB/s gain becomes a commit that the performance graph can show.

## Stage 10 – Coverage Excellence (99%/97% Target)

> **Status:** Not started. Current coverage: 91%/91% (TOONCore/TOONCodable). CI gates at 85%/78%. Goal: ≥99% line, ≥97% branch coverage.

### Strategy

#### Phase 1: Coverage Analysis & Gap Identification
1. **Generate coverage report**
   - Run `swift test --enable-code-coverage`
   - Execute `swift Scripts/coverage-badge.swift --profile .build/debug/codecov/default.profdata --binary-root .build --output coverage-artifacts`
   - Generate HTML report: Find all `.xctest` binaries, run `xcrun llvm-cov show` for each to identify uncovered lines
   
2. **Identify coverage gaps by category**
   - **Error paths:** Exception handling, validation failures, malformed input edge cases
   - **Edge cases:** Empty arrays, single-item collections, maximum-length strings, boundary conditions
   - **Lenient mode paths:** Parser/decoder recovery branches when `lenientArrays: true`
   - **Schema validation paths:** ToonSchema constraint violations, type mismatches
   - **Performance fast paths:** Schema-primed encoder/decoder branches
   - **CLI error handling:** Invalid flags, missing files, pipe failures

#### Phase 2: Systematic Test Addition (TDD)
For each uncovered code segment:

1. **TOONCore (Parser, Lexer, JSONValue)**
   - Add malformed TOON tests: invalid indent patterns, mismatched delimiters, truncated files
   - Test numeric edge cases: MAX_INT, MIN_INT, infinity, NaN, scientific notation boundaries
   - Test string edge cases: empty strings, Unicode edge cases, control characters
   - Test array/object edge cases: empty structures, nested depth limits, key ordering
   - Test error recovery: partial parse success, error message formatting

2. **TOONCodable (Encoder, Decoder, Schema)**
   - Add schema mismatch tests: missing required fields, unexpected fields, type conflicts
   - Test codable edge cases: optional fields, nested optionals, custom CodingKeys
   - Test streaming decoder: chunked reads, interrupted streams, malformed chunks
   - Test analyzer edge cases: mixed-type arrays, sparse objects, ambiguous structures
   - Test serializer edge cases: key collision detection, quoting edge cases, delimiter conflicts

3. **TOONCLI**
   - Add CLI error tests: invalid arguments, missing required flags, contradictory options
   - Test pipe handling: broken pipes, SIGPIPE, partial writes
   - Test file I/O errors: permission denied, disk full, non-existent paths
   - Test stats edge cases: empty files, malformed input with lenient mode

#### Phase 3: Ratchet CI Thresholds
After each test addition batch:
1. Run coverage locally and capture new percentages
2. Update CI thresholds in `.github/workflows/ci.yml` (currently 85/78)
3. Ratchet up by 2-3% increments: `85→88→91→94→97→99%`
4. Commit tests + threshold updates together
5. Push and verify CI passes with new gates

#### Phase 4: Document Untestable Code
If any code paths cannot reach 99%:
1. Add inline `// Coverage: exempt - [reason]` comments
2. Document in `docs/coverage-exceptions.md` with justification
3. Link to GitHub issues for future improvement
4. Examples: platform-specific code, defensive impossible states, deprecated paths

### Deliverables
- [ ] Coverage report HTML published to `gh-pages/coverage/report/`
- [ ] All uncovered lines categorized and ticketed
- [ ] Test suites expanded for each category
- [ ] CI thresholds ratcheted to 99%/97%
- [ ] `docs/coverage-exceptions.md` created if needed
- [ ] Coverage badge shows 99%+ line coverage

### Estimated Timeline
- Phase 1 (Analysis): 1-2 days
- Phase 2 (Test Addition): 5-7 days (iterative, batch commits)
- Phase 3 (Ratcheting): Continuous during Phase 2
- Phase 4 (Documentation): 1 day

## Stage 11 – Performance Optimization to ±10% Target

> **Status:** Not started. Current: Within ±20% tolerance. Goal: Within ±10% of TypeScript reference, demonstrate ≥20% schema-primed gains.

### Strategy

#### Phase 1: Establish Performance Baseline
1. **Current state**
   - Lexer: 5.40 MB/s (+19.9% vs baseline) ✅
   - Parser: 2.67 MB/s (-9.3% regression) ⚠️
   - Decoder: 3.14 MB/s (-17.3% regression) ⚠️
   
2. **Benchmark TypeScript reference**
   - Run `cd reference && pnpm toon encode/decode` with same datasets
   - Capture TypeScript throughput as comparison target
   - Document in `Benchmarks/baseline_typescript.json`

#### Phase 2: Parser Performance Recovery
**Goal:** Recover the -9.3% parser regression

1. **Profile parser hotspots**
   - Run with `SWIFTTOON_PERF_TRACE=1` to see phase durations
   - Use Instruments Time Profiler on `parser_micro` benchmark
   - Identify specific functions consuming most time

2. **Optimization candidates**
   - Review recent commits for unintended allocations
   - Check `parseListArray` changes (moved from explicit length to optional)
   - Profile `buildValue` call overhead
   - Consider inline hints for hot paths
   - Reduce token lookahead overhead

3. **Validate optimizations**
   - Run benchmarks after each change
   - Use `swift Scripts/compare-benchmarks.swift` with 5% tolerance
   - Document in `docs/performance-tracking.md` iteration log

#### Phase 3: Decoder Performance Recovery  
**Goal:** Recover the -17.3% decoder regression

1. **Profile decoder path**
   - Trace `decode_end_to_end` benchmark
   - Identify if regression is in parser or JSONValue→Codable translation
   - Check for JSONSerialization bottlenecks (should be eliminated)

2. **Optimization candidates**
   - Review `JSONValueDecoder` allocations
   - Check container unwrapping overhead
   - Profile keyed/unkeyed container performance
   - Consider caching CodingKey lookups

#### Phase 4: Schema-Primed Fast Path Demonstration
**Goal:** Show ≥20% improvement with schema hints

1. **Create schema-primed benchmark**
   - Add `schema_primed_encode` and `schema_primed_decode` suites
   - Use fixed schema for uniform datasets (users, orders)
   - Compare against default path on same data

2. **Optimize schema path**
   - Skip analyzer when schema provided
   - Pre-allocate based on schema field counts
   - Direct field access instead of reflection
   - Cache serializer format decisions

3. **Document gains**
   - Add benchmark comparison to README
   - Update DocC SchemaPriming tutorial with actual numbers
   - Add to `docs/performance-tracking.md`

#### Phase 5: Additional Micro-Optimizations
Based on profiling, consider:
- String interning for common keys
- Lazy token parsing
- Buffer pooling for large files
- SIMD for numeric parsing
- Custom allocators for temporary structures

### Deliverables
- [ ] TypeScript baseline captured in `Benchmarks/baseline_typescript.json`
- [ ] Parser regression recovered (within -5%)
- [ ] Decoder regression recovered (within -10%)
- [ ] Schema-primed benchmarks show ≥20% improvement
- [ ] All benchmarks within ±10% of TypeScript reference
- [ ] Performance iterations documented in `docs/performance-tracking.md`
- [ ] README perf badge reflects improvements

### Estimated Timeline
- Phase 1 (Baseline): 1 day
- Phase 2 (Parser): 2-3 days
- Phase 3 (Decoder): 2-3 days
- Phase 4 (Schema): 2-3 days
- Phase 5 (Micro-opts): Ongoing/optional

## Stage 12 – Release v0.1.2

> **Status:** Ready to execute. All artifacts prepared, CHANGELOG updated, tests passing.

### Actions
1. Tag release: `gh release create v0.1.2 --title "v0.1.2 - Stage 9 Complete" --notes-file <(grep -A 30 "## \[0.1.2\]" CHANGELOG.md)`
2. Monitor workflows: `gh-commit-watch -w "ci|perf|coverage"`
3. Verify published artifacts on GitHub Releases page
4. Update plan status to mark Stage 9 as released

## Success Criteria

- 100% of official fixtures + differential tests pass on both encode and decode.
- Continuous benchmark suite shows Swift implementation within ±10% of TypeScript throughput; schema-primed path demonstrates ≥20% gain on eligible datasets.
- Test coverage thresholds met (line ≥99%, branch ≥97%) with all code paths exercised via automated tests from day one.
- CLI + library share identical code paths, ensuring end-to-end parity and reproducible performance metrics.
