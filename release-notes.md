## SwiftTOON 0.1.1

- Performance instrumentation: parser `os_signpost` hooks + `ParserPerformanceTracker` so Stage 8 perf iterations are measurable and the MB/s graph stays in sync with each commit.
- Parser throughput tuning: reused shared token buffers for `parseStandaloneValue`, `parseInlineValue`, and `readRowValues`, cutting allocations during the `decode_end_to_end` benchmark and guarding the regression threshold.
- DocC tutorials (Getting Started, Tabular Arrays, Schema Priming) now compile against the real APIs and are referenced from the README/plan so the release narrative is complete.
- Coverage/perf workflow scripted via `Scripts/release-checklist.sh`, updated badges (`gh-pages/perf` + `gh-pages/coverage`), and spec alignment verified by `Scripts/check-spec-alignment.swift`.
