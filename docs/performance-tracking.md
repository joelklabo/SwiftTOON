### Iteration #9 – Peek caching
- **Goal:** Reduce repeated `peekToken(offset: 1)` calls inside `parseListArrayItem` by caching the “upcoming” token once per iteration, trimming a few operations per list entry.
- **Profiling evidence:** `SWIFTTOON_PERF_TRACE=1 swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` still shows `Parser.parseListArray` dominating (~4.7 ms), so minimizing `peekToken` invocations can shave time off each iteration.
- **Optimization steps:** Captured `let upcoming = peekToken(offset: 1)` immediately after retrieving `next`, and reused `upcoming` for both the colon (`:`) and left-bracket (`[`) checks in `parseListArrayItem`.
- **Validation & artifacts:** After the tweak we reran `swift run TOONBenchmarks …`, `swift Scripts/compare-benchmarks … --tolerance 0.05`, `swift Scripts/update-perf-artifacts …`, and `SWIFTTOON_PERF_TRACE=1 …` so the iteration log and badge reflect the micro-optimization.
