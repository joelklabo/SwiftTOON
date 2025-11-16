# DocC Tutorials Checklist

This document tracks the DocC tutorials that stage the SwiftTOON API surface for release. Each tutorial must compile against the real APIs (failing doc tests until the implementation exists) and matches the CLI/manual guidance described in `README.md` and `docs/plan.md`.

| Tutorial | Target Date | Status | Key Snippets | Tests/Validation |
| --- | --- | --- | --- | --- |
| Getting started | TBD | ✅ Completed | Quickstart encode/decode/CLI usage with real `ToonEncoder` / `ToonDecoder` calls and `toon-swift` examples. | `DocC` build must compile the snippets; CI runs the DocC tests as part of `swift test` or DocC bundle validation. |
| Tabular arrays | TBD | ✅ Completed | Show analyzer decisions for uniform arrays, include example fixture from `Tests/TOONCodableTests/Fixtures/encode/representation-manifest.json`, and demonstrate the encoded TOON output via CLI `encode` command sample. | Point to `Tests/TOONCodableTests/ToonArrayAnalyzerTests.swift` to verify the expected behavior. |
| Schema priming | TBD | ✅ Completed | Walk through building `ToonSchema`, primed `ToonEncoder/Decoder`, and mention the benchmark comparison (`TOONBenchmarks` decode throughput). | DocC snippets compile; mention schema priming guards in tests under `Tests/TOONCodableTests/ToonSchemaTests.swift`. |

## Tutorial Requirements

1. Each tutorial must include a short narrative describing the problem, the steps taken, and the expected CLI output.
2. Embed `swift` code fences that compile against the API surface under `Sources/TOONCodable`.
3. Add `XCTExpectFailure`-style references when the API surface is not yet available; remove them once the code ships, keeping DocC red until the work completes.
4. Update this checklist (Status/Notes) whenever a tutorial moves forward so contributors know which doc tests will fail.

## Maintenance Notes

- Keep a pinned `docs/DocCTutorials.md` entry in `docs/plan.md` (see Stage 9) so the tutorials remain part of the release readiness conversation.
- When altering the CLI, encode/decode APIs, or schema structs, revisit the matching DocC snippets and update the “Key Snippets” section to describe the change.
- Run `docc convert` (or the equivalent SwiftPM doc build) as part of the `swift test --enable-code-coverage` workflow once the tutorials exist; document the command and expected outcomes in this file.
