# Changelog

- All notable changes will be documented here. Implementation work is currently focused on documentation, onboarding, and compliance infrastructure; see `docs/plans/plan.md` for the living roadmap.


## [Unreleased]

### Added (2025-11-16)
- Stage 10 coverage tests: 43 new error path tests for Parser and JSONValueDecoder
  - `ParserErrorPathsTests.swift` (17 tests): Array validation, tabular/list errors, lenient mode
  - `JSONValueDecoderErrorTests.swift` (26 tests): Type mismatches, number overflows, container errors

### Changed (2025-11-16)
- Coverage: 91.29% line / 91.08% func / 85.12% region
- Parser error coverage improved from 83.3% → ~88% (estimated)
- JSONValueDecoder error coverage improved from 75.5% → ~85% (estimated)

## [0.1.2] - 2025-11-16
### Added
- DocC tutorials for Getting Started, Tabular Arrays, and Schema Priming
- Spec alignment checker (`Scripts/check-spec-alignment.swift`) with full clause coverage
- Documented spec version (v2.0.0 / commit 3d6c593) in `docs/spec-version.md`

### Fixed
- Encode fixture tests now skip `representation-manifest.json` artifact file
- Schema decoder test corrected to declare proper array length (`items[2]:` not `items[1]:`)

### Changed
- Refactored duplicate scalar formatting code into shared `ScalarFormatter` utility
- Reduced code duplication by ~100 lines across `ToonAnalyzer` and `ToonSerializer`

### Performance
- All benchmarks within ±20% of baseline
- Lexer throughput: 5.40 MB/s (19.9% improvement)
- Parser throughput: 2.67 MB/s (-9.3% regression from recent optimizations)
- Decode end-to-end: 3.14 MB/s (-17.3% from baseline, within tolerance)

## [0.1.1] - 2025-11-15
- Added Stage 8 release/performance instrumentation: parser signposts, buffer reuse, benchmark log template, and guidance so each MB/s gain is documented and plotted.
- Benchmarks/regression guard now run via the scripted pipeline (`Scripts/release-checklist.sh`, perf/coverage badge updates, `Benchmarks/perf-artifacts/*` refreshed).
- README release section and `docs/performance-tracking.md` now point to the live perf/coverage badges plus the `gh-pages/perf/` history graph.

## [0.1.0] - 2025-11-15
- Stage 6 benchmarks + perf artifacts (datasets, scripts, manifest/baseline) plus Stage 5 CLI coverage now pass.
- Release checklist prepared, Stage 7 release plan and artifact scripts are ready for the final publish.
