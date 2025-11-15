# SwiftTOON

[![CI](https://github.com/honk/SwiftTOON/actions/workflows/ci.yml/badge.svg)](https://github.com/honk/SwiftTOON/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/honk/SwiftTOON/branch/main/graph/badge.svg)](https://codecov.io/gh/honk/SwiftTOON)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-ready-orange?logo=swift)](https://swift.org/package-manager/)
[![Swift](https://img.shields.io/badge/Swift-5.10+-FF5E33?logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2013%2B%20%7C%20Linux%20(AArch64%2Fx86_64)-blue)](#platform-support)
[![TOON Spec](https://img.shields.io/badge/TOON%20Spec-v2.0-informational)](https://github.com/toon-format/spec)
[![Style](https://img.shields.io/badge/Lint-SwiftFormat%20%7C%20SwiftLint-4D7A97)](#contributing)
[![Perf Trend](https://img.shields.io/badge/perf%20trend-setup%20in%20progress-lightgrey)](docs/performance-tracking.md)

Token-perfect TOON↔JSON conversion for Swift: zero dependencies, spec-aligned, battle-hardened with exhaustive tests and benchmarks from day one.

---

## Why SwiftTOON?

- **Extreme correctness** – TDD across every layer, nightly fuzzing, and 99%+ coverage enforced in CI.
- **Performance-obsessed** – unsafe-buffer lexing, schema-primed fast paths, and benchmark gates to keep us within 10% of the reference TypeScript encoder/decoder.
- **Drop-in ergonomics** – Codable-compatible encoder/decoder, streaming APIs, and a `toon-swift` CLI for pipelines, scripts, and tooling.
- **Spec parity** – Mirrors the official [TOON v2](https://github.com/toon-format/spec) fixtures and conformance tests; differential testing keeps us byte-for-byte with the upstream CLI.
- **Marketing-ready** – Badges, docs, and stats on the README make it easy to trust and adopt.

> **Status:** Architecture, docs, and CI plan are in place. Implementation starts with strict TDD to keep the coverage, performance, and compliance promises above.

---

## Modules at a Glance

| Target | Purpose | Highlights |
| --- | --- | --- |
| `TOONCore` | Lexer/parser/serializer | Unsafe UTF-8 pipelines, deterministic error taxonomy, JSONValue representation, tabular + list array support |
| `TOONCodable` | Swift Codable bridges | Schema priming, streaming decode/encode, `Data` & `String` helpers |
| `TOONCLI` | `toon-swift` CLI | Encode/decode/validate/stats/subcommands, pipes & files |
| `TOONBenchmarks` | Perf + fuzz harness | Micro/macro benchmarks, regression guard rails, fixture mirroring |

See `docs/plan.md` for the full TDD-driven roadmap.

---

## Getting Started

> 🚧 The APIs below land as soon as their TDD suites go green. Use this section as your reference once we tag `0.1.0`.

### Swift Package Manager

```swift
// Package.swift snippet
dependencies: [
    .package(url: "https://github.com/honk/SwiftTOON.git", from: "0.1.0")
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "TOONCodable", package: "SwiftTOON")
        ]
    )
]
```

### Codable usage

```swift
import TOONCodable

let toonData = try ToonEncoder().encode(myStruct, options: .tabularPreferred)
let model = try ToonDecoder().decode(MyStruct.self, from: toonData)
```

### CLI

```bash
$ toon-swift encode input.json --delimiter ',' --stats
$ toon-swift decode dataset.toon --strict > dataset.json
$ cat data.json | toon-swift encode --lenient
```

---

## Development Setup

1. `swift package resolve` – populate `.build` for linting/tools.
2. `./Scripts/update-fixtures.swift` – mirrors `reference/spec/tests/fixtures` into `Tests/ConformanceTests/Fixtures` and regenerates `manifest.json`.
3. `cd reference && pnpm install && pnpm build` – installs + builds the official CLI so differential tests can call `pnpm exec toon`.
4. `swift test --enable-code-coverage` – runs the placeholder suite (structure + harness checks) to verify the toolchain.
5. Inspect `Benchmarks/baseline_reference.json` (committed stub) to see where perf numbers will be stored for regression gating.

---

## Platform Support

- Swift 5.10 or newer
- macOS 13 Ventura+, Linux (Ubuntu 22.04+, both x86_64 & AArch64)
- Statically-linked, dependency-free binaries for CLI releases

---

## Quality Gates

| Gate | Target |
| --- | --- |
| Line coverage | ≥ 99% |
| Branch coverage | ≥ 97% |
| Spec fixtures | 100% pass (encode & decode) |
| Differential parity | Byte-for-byte vs. TypeScript reference |
| Perf regression | ≤ 5% deviation vs. previous baseline |
| Sanitizers | ASan + TSan clean builds |

Coverage, spec parity, and perf guardrails all surface as shields at the top of this README once the implementation lands.

---

## Performance Tracking

- **Plan:** See [`docs/performance-tracking.md`](docs/performance-tracking.md) for the full benchmarking + visualization pipeline (baseline capture, history storage, badge/graph generation).
- **Datasets:** Canonical TOON/JSON fixtures under `Benchmarks/Datasets/` (large parser stress test, users/orders datasets, CLI round-trips).
- **Local command:** `swift run TOONBenchmarks --format json --output Benchmarks/results/dev.json` (compare against `Benchmarks/baseline_reference.json` using `Scripts/compare-benchmarks.swift` once the helper ships).
- **Automation:** A dedicated GitHub Action will (1) run the suite on macOS ARM runners, (2) push history + Shields endpoint JSON to `gh-pages/perf/`, and (3) refresh the README badge + graph automatically.
- **Coming soon:** Once the workflow lands, this section will show the live graph (`docs/assets/perf-history.png`) sourced from the historical JSON so we can prove performance improves release over release.

---

## Roadmap (TDD Milestones)

1. Fixture + reference harness bootstrapped (`reference/`, generator scripts).
2. Unsafe lexer with exhaustive tests & perf gates.
3. Parser + `JSONValue` builder with error taxonomy + differential suite.
4. Streaming decoder + Codable plumbing + fuzzers.
5. Analyzer & serializer powering encoder + golden TOON fixtures.
6. Schema-primed fast paths, CLI polish, DocC & README sync.

Track detailed steps in [`docs/plan.md`](docs/plan.md).

---

## Contributing

1. Clone repo, install pnpm (Corepack) if you haven't already.
2. `./Scripts/update-fixtures.swift` to sync spec fixtures + manifest.
3. `cd reference && pnpm install && pnpm build` to prep the TypeScript CLI for differential tests.
4. `swift test --enable-code-coverage`
5. (Optional) `swift run TOONBenchmarks --compare Benchmarks/baseline_reference.json` once perf harness lands.
6. Submit PR with green CI, perf notes, and updated docs/context.

We welcome spec discussions, feature ideas, and performance data. Open an issue to chat!

---

## License

MIT © SwiftTOON contributors. The TOON spec itself remains under the upstream license at [toon-format/spec](https://github.com/toon-format/spec).
