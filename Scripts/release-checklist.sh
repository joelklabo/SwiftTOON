#!/usr/bin/env bash
set -euo pipefail

echo "Stage 7 Release Checklist"
echo "1. Run coverage: swift test --enable-code-coverage --parallel"
echo "2. Build DocC: swift test (DocC target) or docc convert"
echo "3. Run benchmarks: swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json"
echo "4. Compare to baseline: swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05"
echo "5. Update perf artifacts: swift Scripts/update-perf-artifacts.swift --latest Benchmarks/results/latest.json --output-dir Benchmarks/perf-artifacts --commit \$(git rev-parse HEAD) --branch \${GITHUB_REF_NAME:-main}"
echo "6. Refresh spec docs: run ./Scripts/check-spec-alignment.swift after updating docs/spec-alignment.md/spec-version.md if needed"
echo "7. Update CHANGELOG.md/README release notes (spec pin, docs, perf badges)"
echo "8. Publish: gh release create \"vX.Y.Z\" --notes-file <notes>"
echo "9. Verify perf/coverage workflows via gh run list"

echo
echo "Tip: rerun this script after editing docs or before tagging to keep the release flow consistent."
