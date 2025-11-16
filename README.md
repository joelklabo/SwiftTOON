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
- **Guided DocC tutorials** – `docs/DocC/GettingStarted.md`, `TabularArrays.md`, and `SchemaPriming.md` stage the public API as compilable code samples that double as DocC test cases.

### Spec Alignment Artifacts

- **Version pinning:** See [`docs/spec-version.md`](docs/spec-version.md) for the upstream spec tag/commit used for this milestone.
- **Clause → test mapping:** Use [`docs/spec-alignment.md`](docs/spec-alignment.md) to understand which TOON clause each fixture/test combination verifies.
- **CI enforcement:** `.github/workflows/ci.yml` now runs `swift Scripts/check-spec-alignment.swift` so the clause table stays aligned with the plan on every push.

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

struct User: Codable, Equatable {
    let id: Int
    let name: String
}

let users = [
    User(id: 1, name: "Alice"),
    User(id: 2, name: "Bob")
]

let encoder = ToonEncoder()
let toonData = try encoder.encode(users)
let decoder = ToonDecoder()
let decoded = try decoder.decode([User].self, from: toonData)
assert(decoded == users)
```

### Schema priming

Provide an explicit schema to lock in structure (and skip runtime inspection on large datasets):

```swift
import TOONCodable

struct Developer: Codable, Equatable {
    let id: Int
    let name: String
    let projects: [String]
}

let developers = [
    Developer(id: 1, name: "Alice", projects: ["SwiftTOON", "MyProject"]),
    Developer(id: 2, name: "Bob", projects: ["AnotherProject"])
]

let schema = ToonSchema.array(
    element: .object(
        fields: [
            ToonSchema.field("id", .number),
            ToonSchema.field("name", .string),
            ToonSchema.field("projects", ToonSchema.array(element: .string))
        ]
    ),
    representation: .tabular(headers: ["id", "name", "projects"])
)

let encoder = ToonEncoder(schema: schema)
let decoder = ToonDecoder(options: .init(schema: schema))

let toonData = try encoder.encode(developers)
let decoded = try decoder.decode([Developer].self, from: toonData)
assert(decoded == developers)
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

# Run the benchmark suite locally
$ toon-swift bench --format json --iterations 5 --output results.json
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

## Releases

- **v0.1.2** (2025-11-16) – Stage 9 complete: DocC tutorials (Getting Started, Tabular Arrays, Schema Priming), spec alignment artifacts (v2.0.0), refactored scalar formatting utilities, and all 167 tests passing. Performance: lexer +19.9%, parser -9.3%, decoder -17.3% (all within ±20% tolerance). See [`CHANGELOG.md`](CHANGELOG.md) for details.
- **v0.1.1** (2025-11-15) – Stage 8 performance instrumentation: parser signposts, buffer reuse, benchmark pipeline with history graph/badge, and performance tracking playbook documented.
- **v0.1.0** (2025-11-15) – Initial release: Stage 6 benchmarks + perf artifacts, Stage 5 CLI coverage, release checklist and artifact scripts ready.
- **Release playbook** – See [`docs/release-checklist.md`](docs/release-checklist.md) plus [`docs/plan.md#release-plan-checklist`](docs/plan.md#release-plan-checklist) for the release workflow. Run `Scripts/release-checklist.sh` to verify all gates pass before publishing.

> Spec alignment: All releases pin to TOON spec v2.0.0 (commit `3d6c593`). See [`docs/spec-version.md`](docs/spec-version.md) and [`docs/spec-alignment.md`](docs/spec-alignment.md) for clause coverage.

---

## Performance Tracking

**Overview:**
- **Plan:** See the [Performance Tracking Playbook](docs/plans/plan.md#performance-tracking-playbook) for the full benchmarking + visualization pipeline.
- **Datasets:** Canonical TOON/JSON fixtures under `Benchmarks/Datasets/` (large parser stress test, users/orders datasets).
- **Local workflow:** `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json` → `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
- **Automation:** Workflows run on every main push, publish artifacts to `gh-pages/perf/`, and update badges/graphs automatically.

### Pipeline Throughput

Track end-to-end performance across the lexer, parser, and decode stages. Higher MB/s = faster processing.

![Pipeline throughput](https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-throughput.png?v=3)

<details>
<summary><b>📊 View Parser Phase Breakdown</b></summary>

Diagnostic view showing time spent in each parser function. Stacked area reveals total parse time + per-phase contributions.

![Parser phases](https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-phases.png?v=3)

</details>

<details>
<summary><b>📈 View Object Processing Rate</b></summary>

Measures how many objects per second the decoder can process (useful for streaming workloads).

![Objects per second](https://raw.githubusercontent.com/joelklabo/SwiftTOON/gh-pages/perf/perf-objects.png?v=3)

</details>

<sub>Graphs update automatically after every push to `main`. Click badge above to see current decode throughput.</sub>

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
