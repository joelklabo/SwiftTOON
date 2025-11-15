# Performance Tracking Plan

Purpose: capture and publish SwiftTOON performance metrics from day one so regressions are caught automatically and visitors see trends directly on the GitHub page (badge + graph).

---

## Step-by-Step Execution

### Step 1 – Author Benchmarks & Fixtures
1. Create canonical datasets under `Benchmarks/Datasets/` (large lexer/parser stress files, representative JSON/TOON pairs) plus `datasets-manifest.json` with SHA256 hashes.
2. Implement benchmark cases in `TOONBenchmarks` (`lexer_micro`, `parser_micro`, `decode_end_to_end`, `encode_end_to_end`, `cli_round_trip`).
3. Add CLI flags so every run can emit JSON:  
   `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`.

### Step 2 – Persist Baselines & Local Guard
1. Capture original measurements in `Benchmarks/baseline_reference.json`.
2. Add `Scripts/compare-benchmarks.swift` to diff new results vs. baseline (tolerance default 5%).
3. Document the local workflow (benchmark command + compare script) in this file, `README.md`, and `docs/agents.md`.

### Step 3 – CI Regression Gate
1. Create `ci-perf.yml` that runs on PRs touching `Sources/` and nightly on `main`.
2. Steps inside the workflow:
   - `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
   - `swift run Scripts/compare-benchmarks Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
3. Fail the job (and therefore the PR) if any metric regresses beyond tolerance; include deltas in logs for clarity.

### Step 4 – History & Visualization Pipeline
1. Add `perf-history.yml` (trigger: push to `main` + nightly) that:
   - Re-runs the benchmark suite.
   - Appends `{commit, timestamp, samples}` to `Benchmarks/history.json`.
   - Publishes history and derived assets to `gh-pages/perf/` using `peaceiris/actions-gh-pages`.
2. Generated artifacts:
   - `perf-history.json` – raw historical data.
   - `perf-history.png` – rendered chart via Matplotlib/QuickChart.
   - `perf-badge.json` – Shields endpoint payload.
3. Exposed URLs:  
   Badge – `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/<org>/<repo>/gh-pages/perf/perf-badge.json`  
   Graph – `https://raw.githubusercontent.com/<org>/<repo>/gh-pages/perf/perf-history.png`

### Step 5 – Surface Data on GitHub
1. Replace the temporary badge in `README.md` with the live Shields endpoint once Step 4 lands.
2. Embed the PNG graph (served from `gh-pages`) inside the README’s “Performance Tracking” section so visitors immediately see throughput trends.
3. Optionally publish an extended view on GitHub Pages (`docs/perf/index.md`) that consumes `perf-history.json` for interactive charts.

### Step 6 – Commit & Plan Hygiene
1. Tackle each step above via focused commits/PRs with descriptive messages (e.g., `perf: add benchmark datasets`, `perf: add compare script`).
2. Update this plan, `docs/plan.md`, `README.md`, and `docs/agents.md` after every milestone so contributors always see the latest workflow.

---

## Local Developer Checklist
1. `swift run TOONBenchmarks --format json --output Benchmarks/results/dev.json`
2. `swift run Scripts/compare-benchmarks Benchmarks/results/dev.json Benchmarks/baseline_reference.json --tolerance 0.05`
3. (Optional) `swift run Scripts/visualize-benchmarks Benchmarks/results/dev.json` to render a local sparkline (future enhancement).

---

## Future Enhancements
- Track memory/allocations alongside throughput.
- Warm benchmarks (discard first run) for stability.
- Add Linux runners for cross-platform data.
- Publish percentile stats (p50/p95) for CLI round-trips.
- Build an interactive GitHub Pages dashboard that consumes `gh-pages/perf/perf-history.json`.
