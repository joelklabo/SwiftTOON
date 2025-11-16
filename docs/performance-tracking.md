# Performance Tracking Manual

This page documents the commands, artifacts, and instrumentation rhythm we follow for Stage 8 so each perf gain is reproducible and visible in the badge/graph.

## Core commands (run before pushing)
1. `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
2. `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
3. `swift Scripts/update-perf-artifacts.swift --latest Benchmarks/results/latest.json --output-dir Benchmarks/perf-artifacts --commit $(git rev-parse HEAD) --branch ${GITHUB_REF_NAME:-main}`
4. Commit `Benchmarks/results/latest.json` and the refreshed `Benchmarks/perf-artifacts/*` alongside any code/perf changes so the gh-pages badge + PNG graph stay current.

## Instrumentation checklist (Stage 8 loop)
- **Time Profiler:** run `swift run TOONBenchmarks --format json --output /tmp/latest.json` while capturing `decode_end_to_end` in Instruments (Time Profiler + CPU). Target `Benchmarks/Datasets/users.toon` (and `large.toon` if you expect different behavior) so the call stack reveals whether `Parser.parse`, `parseValue`, or Codable bridging dominates time.
- **Allocations:** rerun the same suite with Allocations/VM regions enabled to understand heap churn; focus on hot allocators such as `JSONObject.updateValue`, `JSONValue` array builders, or `ToonSerializer.renderEntries`. Record the dominant allocation sites so you can decide whether reuse or pooling helps.
- **Document decisions:** for every hotspot you resolve, paste a snippet of the stack trace + hypothesis into the “Iteration log” below, describe the change (buffer reuse, inline parsing, reduced quoting), and link to the benchmark delta. Include the commands you reran (`swift run TOONBenchmarks …`, `swift Scripts/compare-benchmarks …`, `swift Scripts/update-perf-artifacts …`) so future contributors know how to reproduce the iteration.

## Iteration log template
Each perf iteration should produce:
1. **Goal statement** – clarify what throughput or allocation target you expect to improve.
2. **Profiling evidence** – cite the Instruments template (Time Profiler/Allocations), dataset, and stack frames that drove the change.
3. **Optimization steps** – explain the modifications (e.g., reuse `UnsafeMutableBufferPointer`, inline `parseListArrayItem`, preallocate `JSONObject.entries`).
4. **Validation** – rerun `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`, `swift Scripts/compare-benchmarks.swift …`, and `swift Scripts/update-perf-artifacts.swift …` to capture the delta in `Benchmarks/results/latest.json` + `Benchmarks/perf-artifacts`.
5. **Doc update** – add a short paragraph beneath this template describing the iteration, referencing the Instruments trace file, bench result file, and commit so it’s easy to revisit later.

### Iteration #1 – Parser hotspots
- **Goal:** Identify which parser/decoder paths dominate `decode_end_to_end` so we know where to optimize first.
- **Profiling evidence:** Ran `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` so the new `ParserPerformanceTracker` prints average durations directly to stderr (no Instruments needed). Output:
  - `Parser.parse`: ~0.00420s × 30 iterations
  - `Parser.parseObject`: ~0.00006s × 4030 invocations
  - `Parser.parseArrayValue`: ~0.000008s × 20030 invocations
  - `Parser.parseListArray`: ~0.00417s × 30 iterations
  - `Parser.readRowValues`: ~0.000003s × 4000 invocations
- **Diagnosis:** `Parser.parse` and `Parser.parseListArray` are the slowest sections (per-iteration ~4ms) while helper loops are relatively cheap, so we should reduce per-loop work inside `parseListArray` (maybe reuse buffers or avoid repeated `parseValue` allocations).
- **Validation & artifacts:** Bench command above produced `Benchmarks/results/latest.json`; we still need to run `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05` and `swift Scripts/update-perf-artifacts.swift --latest Benchmarks/results/latest.json --output-dir Benchmarks/perf-artifacts --commit $(git rev-parse HEAD) --branch main` after each optimization.

### Iteration #2 – Reusing token buffers
 - **Goal:** Reduce heap churn inside `parseStandaloneValue`, `parseInlineValue`, and `readRowValues` by reusing their `Token` buffers instead of allocating new `[Token]` arrays per invocation, so we minimize allocations per object field while the parser processes thousands of small objects.
 - **Profiling evidence:** With `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`, each method reports shorter durations: `Parser.parse` ≈3.7 ms, `Parser.parseObject` ≈0.000053 s (down from ~0.000060) and helpers now reuse buffers rather than reallocating.
- **Optimization steps:** Added `chunkBuffer` and `rowChunkBuffer` fields to `Parser`, reused them in `parseStandaloneValue`, `parseInlineValue`, and `readRowValues`, and only cleared them with `removeAll(keepingCapacity: true)` to preserve capacity across iterations.
- **Validation & artifacts:** Bench command above plus `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05` (passes; parser/decoder throughput within tolerance) and `swift Scripts/update-perf-artifacts.swift --latest Benchmarks/results/latest.json --output-dir Benchmarks/perf-artifacts --commit $(git rev-parse HEAD) --branch main`.

### Iteration #3 – BuildValue trimming
- **Goal:** Pay down the small but highly frequent `Parser.buildValue` path by measuring and then optimizing the string trimming step so we avoid repeated copies across its ~26k invocations.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` highlights the new signpost averages: `Parser.parse` ≈0.00446 s, `Parser.parseListArray` ≈0.00445 s, and `Parser.buildValue` ≈0.000001 s × 26 k calls. The high call count suggests trimming should be lighter.
- **Optimization plan:** Tracking is now in place for `buildValue` (see `Parser.buildValue` signpost). The next change will avoid mutating the decoded string per newline and reuse the same slice length computation so `String(decoding:)` isn't allocated multiple times per scalar. We’ll rerun the benchmark/compare/artifact commands after that revision.
- **Validation & artifacts:** The instrumentation run above plus the standard bench/compare/update commands (per the checklist) will be re-run once the trimming change is implemented so the badge and log reflect the improvement.

## Regression story (current iteration)
- Restored the original 100/200-entry `Benchmarks/Datasets/users.toon` + `large.toon` that the baseline expects, reran all benchmarks, and confirmed every suite beats (or matches) the baseline within ±5%.
- Perf artifacts were regenerated so the live badge/graph now reference this clean run (`Benchmarks/perf-artifacts/perf-history.json`, `perf-badge.json`, and `perf-history.png`).
- Keep this file up to date: if a new dataset is introduced or the instrumentation steps change (e.g., new quickchart args), edit this doc so future contributors know exactly how to reproduce the history/badge update.
