# SwiftTOON Agent Handbook

> Canonical context for Codex CLI, Cursor, ClaudeMD, GitHub Copilot, Quad-LLM, and any other AI-assisted workflow. All other agent instruction files MUST link or copy from here to keep guidance consistent.

---

## Mission & Tone

- **Prime directive:** Deliver a zero-dependency Swift library + CLI that encodes/decodes TOON with full spec compliance, 99%+ coverage, and benchmark-driven performance.
- **Mindset:** TDD-first, obsession with correctness/perf, minimal changes outside request scope, concise but friendly communication.
- **Style:** Swift 5.10+, pure SwiftPM layout, documented like production software from day one.

---

## Repository Layout Essentials

- `docs/plan.md` – Living roadmap outlining every stage; reference it before writing code/tests.
- `docs/agents.md` – (this file) canonical instructions for Codex, Cursor, ClaudeMD, Copilot, Quad, etc.
- `reference/` – Upstream `toon-format/toon` checkout for fixtures, differential tests, and performance baselines. Never edit upstream sources except to pull updates.
- `reference/spec` – Spec repository clone providing canonical fixtures; synced via `Scripts/update-fixtures.swift`.
- `README.md` – Public marketing page; badges must stay accurate with active CI workflows.
- `.github/workflows/ci.yml` – Swift test + coverage pipeline; keep it green before merging anything.

Future targets (to be created during implementation) include `Sources/TOONCore`, `Sources/TOONCodable`, `Sources/TOONCLI`, and `Sources/TOONBenchmarks`, plus matching `Tests/` trees with fixtures mirrored from `reference/`.

---

## Golden Rules for All Agents

1. **TDD everything** – Write failing tests (unit/integration/perf) before implementing behavior. No production code without a test proving its necessity.
2. **Coverage first** – Keep line ≥ 99% and branch ≥ 97% in `TOONCore` and `TOONCodable`. If a branch is untestable, document why with a TODO referencing an issue.
3. **Spec fidelity** – Every feature must trace back to TOON v2 spec. Link to relevant sections in code comments when behavior could be ambiguous.
4. **Performance budget** – Use unsafe buffers, avoid allocations, and add benchmarks for any tight loop. Never merge regressions >5% throughput or >10% allocation.
5. **No unapproved deps** – Only Swift stdlib + Foundation (when absolutely needed). If a tool seems helpful (e.g., Swift Argument Parser), discuss before adding.
6. **Docs stay current** – Any behavioral/data/API change must update README, DocC, `docs/plan.md`, this handbook, and downstream context files immediately.
7. **Sync with reference** – Differential tests vs `reference/` TypeScript CLI are mandatory for new encoding/decoding features. Keep fixtures up to date.
8. **Communication** – Summaries must be clear, reference touched files/lines, and propose next steps (tests, docs, benchmarks). No raw command dumps.
9. **Plan + commit hygiene** – Break every substantial task into discrete steps (update `docs/performance-tracking.md` / `docs/plan.md` when plans change) and write descriptive commits that describe *why* and *what* (e.g., `perf: add compare script`, not `update file`). Use `gh-commit-watch` for every commit/push so CI is monitored asynchronously:
   - `gh-commit-watch -m "message" -w "ci|perf|Publish Performance History"` stages all changes, commits, pushes, and spawns a tmux session that tails `gh run watch` for the new workflows.
   - As soon as the tmux window appears, detach (`Ctrl-b d` unless remapped) so you can keep working; reattach later (`tmux attach -t <session>`) or let the session self-close when the runs finish.
   - The default workflow filter is `ci`—pass a comma/pipe list if perf/history runs are relevant to the change.
10. **Schema priming awareness** – When touching encoder/decoder logic, consider whether `ToonSchema` hints (validation + serializer fast paths) need updates. Every new structural feature must have schema-backed tests plus README/DocC coverage.

---

## Workflow Checklist (per task)

1. **Understand request**
   - Read entire issue/PR plus relevant plan sections.
   - Identify whether change belongs to lexer, parser, encoder, CLI, tests, docs, etc.
2. **Plan**
   - Decide if `update_plan` tool is required (non-trivial tasks).
   - Enumerate steps: tests → implementation → perf → docs.
3. **Tests first**
   - Unit tests under `Tests/TOONCoreTests` or relevant target.
   - Integration tests for fixtures under `Tests/ConformanceTests`.
   - CLI/tests use `swift test --filter` for speed when possible.
4. **Implement**
   - Keep functions small, annotate with `@inlinable` when helpful.
   - Document complex logic (indent stack mgmt, schema analyzer).
5. **Validate**
   - Run targeted tests plus `swift test --enable-code-coverage`.
   - Execute perf benchmarks if code touched hot paths (`swift run TOONBenchmarks ...` once target exists).
   - Use reference harness for diff testing when encoding/decoding logic changes.
6. **Docs & README**
   - Update `README.md`, DocC, `docs/plan.md`, this handbook, and every linked context file whenever behavior/features change; highlight any deferred updates.
   - Performance work must also refresh `docs/performance-tracking.md` (plan + checklist) so contributors always know the current process.
7. **Final response**
   - Inline file references (path:line) for modifications.
   - Mention tests/benchmarks run; if skipped, explain why.

---

## Bootstrap Checklist (before running tests)

1. `swift package resolve`
2. `./Scripts/update-fixtures.swift`
3. `cd reference && pnpm install && pnpm build`
4. `swift test --enable-code-coverage`
5. (Optional) `swift run TOONBenchmarks --compare Benchmarks/baseline_reference.json` once perf harness lands.

---

## Swift Package Tasks (canonical commands)

- `swift build` – sanity check compile across all targets.
- `swift test --enable-code-coverage` – default test run (required before PRs).
- `swift test --filter ConformanceTests` – focus on fixture/manifest assertions.
- `swift test --filter ReferenceHarnessTests` – exercises TypeScript CLI bridge; rerun after updating `reference/` or pnpm dependencies.
- `swift test --filter DecoderFixtureTests` – tight loop while bringing new parser/decoder features online.
- `swift test --filter EncodeFixtureTests` – drives the JSON→TOON serializer against all golden fixtures (honors delimiter/indent/key folding options).
- `swift run toon-swift --help` – CLI smoke test; add flags as functionality grows.
- `swift run TOONBenchmarks --compare Benchmarks/baseline_reference.json` – compare perf regressions once benchmarks exist.
- `./Scripts/update-fixtures.swift` – refresh spec fixtures & manifest whenever upstream spec updates or before releasing.
- `cd reference && pnpm install && pnpm build` – install/build upstream CLI (required for diff tests).

Add new commands here whenever tooling grows so every agent has the same reproducible playbook.

---

## Testing Matrix (target commands once package exists)

| Scope | Command | Notes |
| --- | --- | --- |
| Full suite | `swift test --enable-code-coverage` | Run on macOS + Linux via CI. |
| Focused target | `swift test --target TOONCoreTests --filter Lexer` | Use for rapid cycles. |
| Spec fixtures | `swift test --filter ConformanceTests` | Should round-trip `.toon` ↔ `.json`. |
| Differential | `swift run ReferenceDiffTests --fixture users` | Calls TypeScript CLI (requires `pnpm`). |
| Benchmarks | `swift run TOONBenchmarks --compare baseline.json` | Fails if >5% regression. |
| CLI smoke | `swift run toon-swift encode sample.json` | Needed before tagging releases. |

> Until the Swift package scaffolding exists, reference these commands in planning but skip running them (explain in final notes).

---

## Reference Harness Expectations

- `Scripts/update-fixtures.swift` mirrors `reference/spec/tests/fixtures` into `Tests/ConformanceTests/Fixtures`, normalizes line endings, and emits `manifest.json` with SHA256 + spec version.
- Before running tests, execute `cd reference && pnpm install && pnpm build` so the TypeScript CLI exists at `reference/packages/cli/dist`.
- Fixtures mirror spec repo: ensure generator script copies `.toon`, `.json`, `.md` metadata with SHA recorded.
- Conformance tests iterate fixtures:
  - Swift decode → JSON matches fixture JSON via canonicalizer.
  - Swift encode → TOON equals fixture string.
  - Differential decode/encode vs TypeScript CLI to catch divergences.
- Keep `reference/` on tagged release; document version in `docs/plan.md`.

---

## Performance Playbook

- Microbenchmarks: isolated lexer, parser, serializer tasks – track MB/s, allocations using `swift test --filter Perf` or `swift run TOONBenchmarks`.
- Macrobenchmarks: dataset-based, e.g., 100k rows uniform vs nested.
- Baselines stored in JSON (commit into repo) and compared automatically; update only after intentional improvements and include justification in PR.
- For major perf work, capture Instruments/`perf` profiles and summarize hotspots in PR/commit message.
- Read [`docs/performance-tracking.md`](performance-tracking.md) for the end-to-end telemetry/graph plan (history JSON, Shields endpoint, README badge expectations).
- Local perf workflow (run before pushing perf-sensitive changes):
  1. `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
  2. `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
- Use `gh` freely for repo inspection: e.g. `gh run list`, `gh run view <id> --log`, `gh issue status`, etc., to diagnose CI failures or workflow status quickly. Capture relevant snippets in final summaries when the CLI output explains a fix.

---

## Coding Standards

- Indentation: 4 spaces (Swift default). Keep lines ≤ 120 chars when practical.
- Comments: only for non-obvious logic (indent stack transitions, quoting rules). Reference spec sections.
- Errors: define `TOONError` enum with cases for syntax, semantic, validation, IO. Always include `line:column`.
- Public API doc comments must state performance and safety expectations (e.g., “Streaming decoder is zero-copy; caller must ensure buffer remains alive”).
- Avoid `fatalError` outside tests; use throwing APIs.
- Keep enums/f structs `internal` by default; expose only what’s necessary.

---

## CLI & Tooling Expectations

- `toon-swift` should mirror TypeScript CLI flags: `encode`, `decode`, `validate`, `stats`, `--delimiter`, `--lenient`, `--strict`.
- Provide piping support (stdin/stdout) and file arguments.
- `--stats` prints JSON summary (bytes saved, token estimates from heuristics).
- Document CLI usage in README with examples; add snapshot tests for output.

---

## Documentation

- README badges (CI, coverage, Swift version, platforms, spec) must stay accurate; update URLs if org/project changes.
- DocC tutorials: “Getting started”, “Tabular arrays”, “Schema priming”.
- `docs/plan.md` is authoritative for roadmap; update when scope changes or stages complete.
- Add `CHANGELOG.md` before first release; follow Keep a Changelog format.

---

## Sync Strategy for Agent Files

- `docs/agents.md` is the canonical source.
- Create symlinks (or CI copying) for:
  - `AGENTS.md` (root) – so humans see instructions immediately.
  - `.github/copilot-instructions.md` – consumed by GitHub Copilot.
  - `CLAUDE.md` – consumed by ClaudeMD or other Anthropic-specific tooling.
  - `docs/cursor/rules.md` (future) – Cursor custom instructions can point here or include this file.
- If a platform can’t read symlinks, add a short stub pointing to this document and set up a script to refresh copies.
- When editing instructions, only modify this file; regenerate/copy symlinks afterward.

---

## FAQ

- **Q:** Do we ever skip tests for small doc tweaks?  
  **A:** Docs-only changes don’t require `swift test`, but mention in final note that no code changed.
- **Q:** How to introduce a dependency like Swift Argument Parser?  
  **A:** Open design issue, explain benefits vs constraints, wait for approval before adding to `Package.swift`.
- **Q:** How to handle upstream spec changes?  
  **A:** Update `reference/`, re-run fixture generator, adjust tests/plan/README to reflect new spec version, and tag release.

---

Stay disciplined, keep everything measurable, and treat every change as if it ships to production immediately.
