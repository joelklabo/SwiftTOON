# Changelog

- All notable changes will be documented here. Implementation work is currently focused on documentation, onboarding, and compliance infrastructure; see `docs/plan.md` for the living roadmap.


## [Unreleased]
- DocC tutorials verified and README sections mirrored.

## [0.1.1] - 2025-11-15
- Added Stage 8 release/performance instrumentation: parser signposts, buffer reuse, benchmark log template, and guidance so each MB/s gain is documented and plotted.
- Benchmarks/regression guard now run via the scripted pipeline (`Scripts/release-checklist.sh`, perf/coverage badge updates, `Benchmarks/perf-artifacts/*` refreshed).
- README release section and `docs/performance-tracking.md` now point to the live perf/coverage badges plus the `gh-pages/perf/` history graph.

## [0.1.0] - 2025-11-15
- Stage 6 benchmarks + perf artifacts (datasets, scripts, manifest/baseline) plus Stage 5 CLI coverage now pass.
- Release checklist prepared, Stage 7 release plan and artifact scripts are ready for the final publish.
