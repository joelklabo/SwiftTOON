# Performance Tracking Plan

This document describes how SwiftTOON will measure, persist, and publicly surface encode/decode performance over time. The goals are:

- Capture stable, repeatable throughput/latency numbers for core workloads (lexer, parser, decoder, encoder, CLI).
- Detect regressions automatically (CI failure if a hotspot slows by >5%).
- Publish history so contributors and users can see the trend on the README (graph + badge).
- Keep the workflow frictionless: a single command gathers metrics locally, and GitHub Actions update history + badges on every main-branch push/nightly run.

## 1. Benchmarks & Metrics

| Suite | Dataset | Metric | Notes |
| --- | --- | --- | --- |
| `lexer_micro` | `Fixtures/perf/large.toon` | MB/s, allocations/op | Focuses on tokenisation only. |
| `parser_micro` | `Fixtures/perf/large.toon` | MB/s, allocations/op | Measures AST build without JSON bridging. |
| `decode_end_to_end` | `Fixtures/perf/users.toon` | objs/sec, p95 latency | Full decode → `JSONValue`. |
| `encode_end_to_end` | `Fixtures/perf/users.json` | objs/sec, p95 latency | Analyzer + serializer stack. |
| `cli_round_trip` | `Fixtures/perf/orders.json` | wall-clock | Executes `toon-swift encode/decode` via CLI to cover I/O. |

All metrics are emitted as JSON records (`suite`, `dataset`, `metric`, `value`, `unit`, `commit`, `timestamp`, `runner`).

## 2. Harness Implementation

1. Extend the existing `TOONBenchmarks` target with a `--format json --output <file>` option.
2. Each benchmark writes `BenchmarkSample` structs, and the harness appends them to a single array before exiting.
3. Add fixtures under `Benchmarks/Datasets/` with canonical JSON/TOON pairs. Include SHA256 manifest to ensure inputs never drift.
4. Add `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` to the Agent handbook so every agent collects metrics the same way.

## 3. Baseline + Regression Guard

1. Store the current baseline in `Benchmarks/baseline_reference.json` (committed).
2. Ship a script `Scripts/compare-benchmarks.swift` that:
   - Reads the latest results + baseline.
   - Computes % delta per `(suite, dataset, metric)`.
   - Exits non-zero if any slowdown exceeds 5% (configurable via `--tolerance`).
3. CI job `ci-perf.yml` runs on every PR touching `Sources/` and on `main` nightly:
   ```bash
   swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json
   swift run Scripts/compare-benchmarks Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05
   ```

## 4. History & Visualization Pipeline

1. Introduce a GitHub Action `perf-history.yml` (triggered on main + nightly) that:
   - Runs the benchmark command.
   - Appends a compact record `{"commit":"abc","timestamp":"...","samples":[...]}` to `Benchmarks/history.json`.
   - Commits the updated history to the `gh-pages` branch (or a dedicated `perf-history` branch) using the `actions/checkout` + `peaceiris/actions-gh-pages` combo.
2. In the same workflow, generate artifacts for visualization:
   - `docs/assets/perf-history.json` (subset for README).
   - `docs/assets/perf-history.png`: use `python -m pip install matplotlib` (or `npx quickchart-cli`) to render a line chart of decode/encode throughput vs. commit index.
   - `docs/assets/perf-badge.json`: create a Shields endpoint payload:
     ```json
     { "schemaVersion": 1, "label": "decode (MB/s)", "message": "125", "color": "brightgreen" }
     ```
   - Upload PNG + JSON to `gh-pages/perf/`.
3. Expose artifacts:
   - Badge URL: `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/honk/SwiftTOON/gh-pages/perf/perf-badge.json`
   - Graph URL: `https://raw.githubusercontent.com/honk/SwiftTOON/gh-pages/perf/perf-history.png`

## 5. README Integration

1. Add a placeholder badge now, linking to this doc. Replace it with the Shields endpoint once the action writes `perf-badge.json`.
2. Create a “Performance Tracking” section summarizing:
   - The benchmark suites tracked.
   - How to reproduce locally.
   - Links to the live badge + graph once available.
3. When the GitHub Action starts publishing artifacts, update the README image + link (`![Perf graph](https://raw.githubusercontent.com/...)`).

## 6. Local Developer Workflow

1. `swift run TOONBenchmarks --format json --output Benchmarks/results/dev.json`
2. `swift run Scripts/compare-benchmarks Benchmarks/results/dev.json Benchmarks/baseline_reference.json`
3. Optional: `Scripts/visualize-benchmarks.swift Benchmarks/results/dev.json` to render a local sparkline (Swift script calling `SwiftPlot` or piping to `gnuplot`).

Document these commands in:

- `docs/agents.md` (already tracked via “Swift Package Tasks”).
- `docs/performance-tracking.md` (this file) for deeper context.

## 7. Future Enhancements

- Capture memory/allocations (via `MallocStackLogging` or `instruments` CLI) and add them to the JSON schema.
- Use cache warming (run each benchmark twice, discard the first run) for stable numbers.
- Add multi-platform perf jobs (Linux x86_64 runner) to compare macOS vs. Linux throughput.
- Publish percentile metrics (p50/p95) for CLI round-trips using multiple iterations.
- Create a GitHub Pages dashboard (simple static site) that fetches `history.json` and renders interactive charts with `Chart.js`.

With this plan in place, we can start collecting baseline data immediately and progressively automate the visualization without blocking core development. All future performance improvements will be visible on the README through the badge + graph, providing instant feedback to contributors and users.***
