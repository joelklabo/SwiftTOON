# Benchmark Datasets

This directory holds representative TOON files used by `TOONBenchmarks` (`lexer_micro`, `parser_micro`, `decode_end_to_end`, etc.).

## Structure
- `large.toon` – A stress test for the lexer + parser using nested objects.
- `users.toon` – A dataset leveraged by decoder throughput and columnar analyses.

## Updating
1. Run `scripts/generate-benchmark-data.swift` (once implemented) or manually craft new `.toon` files that reflect real workload scenarios.
2. Re-run `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`.
3. Feed the resulting JSON into `Scripts/update-perf-artifacts.swift` to refresh `Benchmarks/perf-history.json`, `perf-badge.json`, and the QuickChart graph referenced in `README.md`.

Document any new datasets in this file so Stage 6 benchmark planning stays current with the artifacts you capture.
