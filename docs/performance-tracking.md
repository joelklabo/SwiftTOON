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
1. Capture original measurements in `Benchmarks/baseline_reference.json` (JSON wrapper containing `generatedAt` + `samples`).
2. Add `Scripts/compare-benchmarks.swift` (run via `swift Scripts/compare-benchmarks.swift latest baseline --tolerance 0.05`) to diff new results vs. the committed baseline.
3. Store ad-hoc benchmark runs in `Benchmarks/results/latest.json` (ignored by Git) so contributors can repeat the workflow without polluting commits.
4. Document the local workflow (benchmark command + compare script) in this file, `README.md`, and `docs/agents.md`.

### Step 3 – CI Regression Gate
1. `perf.yml` workflow runs on macOS 14 for every push/PR touching perf-sensitive paths (and is manually runnable).
2. Steps inside the workflow:
   - Checkout repo.
   - `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
   - `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
   - Upload the JSON artifact for debugging.
3. The workflow fails the build if any benchmark deviates beyond tolerance or if samples are missing, giving immediate regression feedback.

### Step 4 – History & Visualization Pipeline
1. `perf-history.yml` (trigger: push to `main` + manual dispatch) reruns the suite, compares against the baseline (tolerance currently 20% on CI runners), and then uses `Scripts/update-perf-artifacts.swift` to append `{commit, timestamp, samples}` to a history file.
2. Artifacts written to `perf-artifacts/`:
   - `perf-history.json` – the entire history (metadata + entries).
   - `perf-badge.json` – Shields endpoint payload (decode throughput MB/s).
   - `perf-history.png` – QuickChart-generated line chart of decode throughput over time.
   - `meta.json` – repo/branch metadata for debugging.
3. `peaceiris/actions-gh-pages` publishes the artifacts to `gh-pages/perf/`, making them available via:
   - Badge – `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-badge.json`
   - Graph – `https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-history.png`

### Step 5 – Surface Data on GitHub
1. Replace the temporary badge in `README.md` with the live Shields endpoint once Step 4 lands.
2. Embed the PNG graph (served from `gh-pages`) inside the README’s “Performance Tracking” section so visitors immediately see throughput trends.
3. Optionally publish an extended view on GitHub Pages (`docs/perf/index.md`) that consumes `perf-history.json` for interactive charts.

### Step 6 – Commit & Plan Hygiene
1. Tackle each step above via focused commits/PRs with descriptive messages (e.g., `perf: add benchmark datasets`, `perf: add compare script`).
2. Update this plan, `docs/plan.md`, `README.md`, and `docs/agents.md` after every milestone so contributors always see the latest workflow.

---

## Coverage Telemetry (Codecov Replacement)

### Goal
Surface real SwiftPM coverage numbers without any third-party SaaS dependency so badges stay accurate even if Codecov tokens are missing. Reuse the same gh-pages approach that already powers the performance badge/graph.

### Plan
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

### Future Enhancements
- Track historical coverage trends (store `coverage-history.json` alongside the badge and render a sparkline similar to perf).
- Emit per-target coverage so we can spot regressions isolated to `TOONCore` vs `TOONCLI`.
- Gate merges on minimum coverage thresholds once data stabilizes (e.g., fail CI if `<99%` line coverage).

---

## Local Developer Checklist
1. `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
2. `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
3. (Optional) `swift run Scripts/visualize-benchmarks Benchmarks/results/dev.json` to render a local sparkline (future enhancement).

---

## Future Enhancements
- Track memory/allocations alongside throughput.
- Warm benchmarks (discard first run) for stability.
- Add Linux runners for cross-platform data.
- Publish percentile stats (p50/p95) for CLI round-trips.
- Build an interactive GitHub Pages dashboard that consumes `gh-pages/perf/perf-history.json`.
- Mirror the coverage badge plan for mutation testing or fuzzing depth once those harnesses exist.
