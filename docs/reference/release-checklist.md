# Release Checklist

This document outlines the steps every release must follow so the DocC tutorials, performance tracking, coverage telemetry, and spec alignment remain reproducible.

1. **Refresh spec artifacts**
   - Run `./Scripts/update-fixtures.swift` if the upstream `reference/spec` has changed.
   - Re-run `swift Scripts/check-spec-alignment.swift` to confirm every clause and fixture from `Tests/ConformanceTests/Fixtures/manifest.json` is documented.
   - Update `docs/spec-version.md` with the new `reference/spec` commit/tag.

2. **DocC & README**
   - Ensure `Sources/SwiftTOONDocC/SwiftTOON.docc` includes the tutorials tracked in `docs/DocCTutorials.md`.
   - Rebuild DocC (via `docc convert` or `swift test --enable-code-coverage` after the DocC target exists) and confirm no failures.
   - Update the README `Releases` and `Spec Alignment Artifacts` sections if anything shifts.

3. **Coverage & perf**
   - Run `swift test --enable-code-coverage --parallel`.
   - Execute `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` and compare against `Benchmarks/baseline_reference.json` via `swift Scripts/compare-benchmarks.swift`.
   - Run the coverage badge script (`swift Scripts/coverage-badge.swift ...`) so the telemetry artifacts match the new run.

4. **CHANGELOG & packaging**
   - Draft the next `CHANGELOG.md` entry per [Keep a Changelog](https://keepachangelog.com/).
   - Confirm `Package.swift` (platform matrix, swift-tools-version), `Package.resolved`, and README badges reference the upcoming release/spec version.

5. **Publish**
   - Use `gh release create <tag> ...` (manual or scripted, e.g., `gh release create "${TAG}" --title ... --notes-file ...`).
   - Use `gh-commit-watch -w perf|coverage` to watch the perf and coverage workflows triggered by the release.
   - Update the README `Releases` summary bullet to describe the new version + spec tag + performance/coverage highlights.

Refer back to `docs/plans/plan.md#release-checklist` for extra detail (DocC/perf/coverage gating plus spec alignment). Keep this file in sync with the plan whenever workflows change.
