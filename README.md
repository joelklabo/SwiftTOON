# SwiftTOON

[![CI](https://github.com/joelklabo/SwiftTOON/actions/workflows/ci.yml/badge.svg)](https://github.com/joelklabo/SwiftTOON/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-badge.json&cacheSeconds=600)](https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-summary.json)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-ready-orange?logo=swift)](https://swift.org/package-manager/)
[![Swift](https://img.shields.io/badge/Swift-5.10+-FF5E33?logo=swift)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2013%2B%20%7C%20Linux%20(AArch64%2Fx86_64)-blue)](#platform-support)
[![TOON Spec](https://img.shields.io/badge/TOON%20Spec-v2.0-informational)](https://github.com/toon-format/spec)
[![Style](https://img.shields.io/badge/Lint-SwiftFormat%20%7C%20SwiftLint-4D7A97)](#contributing)
[![Perf Trend](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-badge.json&cacheSeconds=600)](https://joelklabo.github.io/SwiftTOON/perf/)

Token-perfect TOON↔JSON conversion for Swift: zero dependencies, spec-aligned, battle-hardened with exhaustive tests and benchmarks from day one.

---

## Why SwiftTOON?

- **Extreme correctness** – TDD across every layer, nightly fuzzing, and 99%+ coverage enforced in CI.
- **Performance-obsessed** – unsafe-buffer lexing, schema-primed fast paths, and benchmark gates to keep us within 10% of the reference TypeScript encoder/decoder.
- **Drop-in ergonomics** – Codable-compatible encoder/decoder, streaming APIs, and a `toon-swift` CLI for pipelines, scripts, and tooling.
- **Pure Swift Codable pipeline** – Custom `JSONValue` encoder/decoder keeps conversion dependency-free (no `JSONSerialization` hops) while respecting schema validation.
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

let toonData = try ToonEncoder().encode(myStruct)
let model = try ToonDecoder().decode(MyStruct.self, from: toonData)
```

### Schema priming

Provide an explicit schema to lock in structure (and skip runtime inspection on large datasets):

```swift
import TOONCodable

let schema = ToonSchema.array(
    element: .object(
        fields: [
            .field("id", .number),
            .field("name", .string),
        ],
        allowAdditionalKeys: false
    ),
    representation: .tabular(headers: ["id", "name"])
)

var encoder = ToonEncoder(schema: schema)
var decoder = ToonDecoder(options: .init(schema: schema))

let toonData = try encoder.encode(users)
let decoded = try decoder.decode([User].self, from: toonData)
```

### CLI

`toon-swift` already exposes three zero-dependency subcommands that mirror the TypeScript reference tool. All commands accept an optional input path (defaulting to STDIN) and write to STDOUT unless `--output` is supplied.

```bash
# Encode JSON → TOON
$ toon-swift encode payload.json --output payload.toon
$ cat payload.json | toon-swift encode > payload.toon

# Decode TOON → JSON
$ toon-swift decode payload.toon --output payload.json
$ cat payload.toon | toon-swift decode > payload.json

# Compare sizes (custom delimiter + indent)
$ toon-swift stats payload.json --delimiter tab --indent 4

# Validate TOON (strict or lenient parsing)
$ toon-swift validate payload.toon --lenient
```

`encode` accepts `--delimiter <comma|tab|pipe>` and `--indent <n>` so you can control emitted TOON formatting. `decode`/`validate` accept `--strict` (default) or `--lenient`; lenient mode relaxes tabular row validations (missing fields are padded with `null`, extra fields are truncated). `stats` prints a JSON blob such as `{ "jsonBytes": 512, "toonBytes": 312, "reductionPercent": 39.0 }`, which makes it easy to script reports or feed dashboards.

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
- **Local command:** `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` followed by `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json` to ensure no regressions before you push.
- **Automation:** The `Performance Benchmarks` workflow (`.github/workflows/perf.yml`) runs the suite on macOS runners for every push/PR, compares against `Benchmarks/baseline_reference.json`, and uploads the JSON output. A companion workflow (`perf-history.yml`) reruns the suite on main pushes, aggregates results into `gh-pages/perf/`, and publishes a Shields badge + line chart so visitors can track throughput.
- **Live artifacts:** The graph below and the README badge are sourced from `https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/` and refresh after every main-branch run of `perf-history.yml`.

![Performance history graph](https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-history.png)

<sub>Higher MB/s numbers mean faster decoders (so the ideal trend is up and to the right). The badge and graph update automatically after the `Publish Performance History` workflow runs on `main`.</sub>

---

## Coverage Reporting

- **Zero dependency telemetry:** Instead of relying on Codecov, we run `swift test --enable-code-coverage --parallel` and feed the LLVM profile into [`Scripts/coverage-badge.swift`](Scripts/coverage-badge.swift). The script calls `llvm-cov export -summary-only …` so the percent matches SwiftPM’s notion of coverage exactly.
- **Automation:** `.github/workflows/coverage.yml` executes on every push to `main`, generates `coverage-badge.json` + `coverage-summary.json`, and publishes them to `gh-pages/coverage/` using the same mechanism as the perf artifacts.
- **Live badge:** The README badge above hits `https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/coverage/coverage-badge.json` (cached for 10 minutes). Clicking the badge opens the raw summary JSON with counts/percentages for lines, functions, and regions plus metadata (commit, branch, timestamp).
- **Local workflow:** Run the script locally before pushing if you touch anything coverage-sensitive:
  1. `swift test --enable-code-coverage --parallel`
  2. `swift Scripts/coverage-badge.swift --profile $(find .build -path "*/codecov/default.profdata" -print -quit) --binary-root .build --output coverage-artifacts --label coverage`
  3. Inspect `coverage-artifacts/coverage-summary.json` to confirm no regressions, then clean up (`rm -rf coverage-artifacts`) before committing.
- **Coming soon:** Once implementation stabilizes we’ll fail CI if line coverage dips below 99%, and we’ll add a coverage sparkline similar to the perf chart.

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
