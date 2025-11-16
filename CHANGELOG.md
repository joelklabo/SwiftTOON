# Changelog

- All notable changes will be documented here. Implementation work is currently focused on documentation, onboarding, and compliance infrastructure; see `docs/plans/plan.md` for the living roadmap.


## [Unreleased]

## [0.1.3] - 2025-11-16

### Added
- **Stage 10 Coverage Sprint:** +180 comprehensive tests (556 → 588 expected)
  - `ParserRemainingCoverageTests.swift` (29 tests): Array edge cases, lenient mode
  - `JSONValueDecoderRemainingTests.swift` (15 tests): Nested containers, type conversions
  - `ParserUncoveredPathsTests.swift` (21 tests): Delimiters, nesting, whitespace
  - `ParserSurgicalCoverageTests.swift` (15 tests): List items, EOF handling
  - `ParserParseValueTriggerTests.swift` (10 tests): Unusual tokens - BREAKTHROUGH
  - `ParserPerformanceTrackerTests.swift` (7 tests): Performance tracking APIs
  - `ParserErrorPathsTests.swift` (+6 tests, 23 total): Error path coverage
  - `LexerEdgeCaseTests.swift` (13 tests): Line endings, character errors
  - `ParserFinalGapsTests.swift` (13 tests): Final coverage push
  - `JSONValueDecoderComprehensiveTests.swift` (18 tests): Latest additions
  - `ToonSchemaComprehensiveTests.swift` (32 tests): .any, .null, nested validation
- **CI Infrastructure:** Chained workflows for cost optimization
  - Coverage Badge triggers after CI success (not parallel)
  - Performance Benchmarks triggers after CI success
  - Publish Performance History split into macOS benchmark + Linux publish
  - **Cost savings: 44% on success, 80% on test failures**
- **Coverage Analysis:** Detailed gap analysis in `docs/plans/coverage-gaps-2025-11-16.md`
  - Priority modules identified with 4-phase action plan
  - Per-module line/region coverage breakdown

### Changed
- **Coverage: 91.29% → 92.73% line (+1.44%, +180 tests)**
  - Parser: 83.73% → 91.64% (+7.91%) 🏆 Biggest win
  - Lexer: 95.70% → 97.68% (+1.98%) ⭐ Near perfection
  - TOONCore: 88.40% → 92.29% (+3.89%)
  - JSONValueDecoder: 76.63% → ~91.30% (+14.67%)
  - TOONCodable: 95.48% → 96.52% (+1.04%)
- **CI Workflows:** Implemented dependency chaining (ci → quality → publish)
  - Reduces wasted macOS runner minutes when tests fail
  - Uses ubuntu-latest for artifact publishing (free tier)
  - Annual savings: ~107,000-192,000 CI minutes

### Infrastructure
- Updated `docs/plans/plan.md` with coverage sprint results
- Added session summaries documenting progress
- Created `coverage-gaps-2025-11-16.md` with detailed action plan

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
