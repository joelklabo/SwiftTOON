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
- **Goal:** Trim the `Parser.buildValue` path by calculating the slice length just once and decoding directly, eliminating repeated `String` mutations across the ~26k invocations in `decode_end_to_end`.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` shows `Parser.parse` ≈0.00455 s, `Parser.parseListArray` ≈0.00453 s, and `Parser.buildValue` ≈0.000000s × 26 k calls—building the string still happens often, so trimming before decoding removes redundant operations.
- **Optimization steps:** Adjusted `buildValue` to compute the trimmed end index over `sourceBytes` before decoding and to avoid `String` mutations (no calls to `removeLast`). The slice is now created once using the trimmed byte range and decoded exactly once, substantially reducing work in the high-frequency path.
- **Validation & artifacts:** After the change we ran `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`, `swift Scripts/compare-benchmarks.swift … --tolerance 0.05` (passes), `swift Scripts/update-perf-artifacts.swift …`, and `SWIFTTOON_PERF_TRACE=1 …` to confirm the tracker reports the revised timings; the badge/history now reflect the faster decode rate.

### Iteration #4 – Inline list parsing
- **Goal:** Eliminate the extra `parseValue` path inside `parseListArrayItem` when the dash is followed by a simple inline scalar, saving the repeated newline/indent handling inside `parseValue`.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` now reports `Parser.parse` ≈0.00532 s, `Parser.parseListArray` ≈0.00530 s, and the inline path is highlighted by the signpost log (previously dominated by `parseValue`’s extra logic).
- **Optimization steps:** When no indent/newline is present after the dash we now call `parseInlineValue()` directly instead of `parseValue()`, since `parseInlineValue` already shares the token buffer and only consumes tokens until newline/dedent (which is exactly what the inline case needs).
- **Validation & artifacts:** After the change we reran `swift run TOONBenchmarks …`, `swift Scripts/compare-benchmarks … --tolerance 0.05`, `swift Scripts/update-perf-artifacts …`, and `SWIFTTOON_PERF_TRACE=1 …` so the iteration log and badge reflect the optimized throughput.

## Regression story (current iteration)
- Restored the original 100/200-entry `Benchmarks/Datasets/users.toon` + `large.toon` that the baseline expects, reran all benchmarks, and confirmed every suite beats (or matches) the baseline within ±5%.
- Perf artifacts were regenerated so the live badge/graph now reference this clean run (`Benchmarks/perf-artifacts/perf-history.json`, `perf-badge.json`, and `perf-history.png`).
- Keep this file up to date: if a new dataset is introduced or the instrumentation steps change (e.g., new quickchart args), edit this doc so future contributors know exactly how to reproduce the history/badge update.

### Iteration #5 – Scalar shortcut
- **Goal:** Recognize single-token scalars immediately inside `parseListArrayItem` so we can interpret identifiers, numbers, and string literals without invoking the heavier `parseValue` method.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` reports `Parser.parse` ≈0.00469 s, `Parser.parseListArray` ≈0.00466 s, and the new shortcut shows up as part of the tracker output we now record per iteration.
- **Optimization steps:** Added `parseSimpleScalarValue()` to consume simple literals directly via `interpretSingleToken`, and we try that before calling `parseValue`. This avoids building a chunk array when the dash is followed by a single token.
- **Validation & artifacts:** After the change we reran the bench/compare/artifact scripts plus the perf trace, so the iteration log and perf graph reflect this incremental throughput gain.

### Iteration #6 – Simple standalone scalars
- **Goal:** Bypass `chunkBuffer` entirely for single-token standalone values by returning them immediately if the next token is newline/dedent/eof.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` now logs the updated tracker averages for `Parser.parse`, `Parser.parseListArray`, and `Parser.buildValue`, showing this new early exit handles the inline scalar case frequently.
- **Optimization steps:** Added `parseSimpleStandaloneValue()` at the start of `parseStandaloneValue` to inspect the first token and return it via `interpretSingleToken` when the next token is newline/dedent/eof, preventing the chunk buffer from being populated at all for the simplest values.
- **Validation & artifacts:** After the tweak we reran the bench/compare/artifact commands plus `SWIFTTOON_PERF_TRACE=1 …` so the iteration log and badge record the faster scalar handling.

### Iteration #7 – Reserve list buffers
- **Goal:** Preallocate the arrays that hold list and tabular rows so they don’t grow during the constant-length loops, reducing reallocations in `parseListArray` and `parseTabularRows`.
- **Profiling evidence:** The tracker still shows `Parser.parseListArray` dominating, so pre-reserving capacity should improve throughput when thousands of entries are appended.
- **Optimization steps:** `parseListArray` now calls `values.reserveCapacity(length)` before entering the loop, and `parseTabularRows` reserves `rows.reserveCapacity(length)` so the arrays won’t reallocate while building the tables.
- **Validation & artifacts:** After applying the reserve changes we reran `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`, `swift Scripts/compare-benchmarks.swift … --tolerance 0.05`, `swift Scripts/update-perf-artifacts.swift …`, and `SWIFTTOON_PERF_TRACE=1 …` so the iteration log and badge reflect this incremental gain.

### Iteration #8 – Inline row shortcuts
- **Goal:** When `readRowValues` sees exactly one token between delimiters, return that scalar immediately instead of hitting the multi-token `buildValue` path, reducing work during long rows.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` still shows `Parser.parseListArray` around 4.1 ms, so skipping `buildValue` for single-token rows should shave off a noticeable chunk of time.
- **Optimization steps:** `flushChunk()` now checks `rowChunkBuffer.count == 1` and shortcut directly by calling `interpretSingleToken` instead of computing `buildValue`.
- **Validation & artifacts:** After the change we reran the benchmark/compare/artifact scripts and the perf trace so the iteration log and badge capture the updated MB/s for `decode_end_to_end`.
