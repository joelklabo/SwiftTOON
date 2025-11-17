# SwiftTOON Agent Handbook

> Canonical context for Codex CLI, Cursor, ClaudeMD, GitHub Copilot, Quad-LLM, and any other AI-assisted workflow. All other agent instruction files MUST link or copy from here to keep guidance consistent.

---

## Mission & Tone

- **Prime directive:** Deliver a zero-dependency Swift library + CLI that encodes/decodes TOON with full spec compliance, 99%+ coverage, and benchmark-driven performance.
- **Mindset:** TDD-first, obsession with correctness/perf, minimal changes outside request scope, concise but friendly communication.
- **Style:** Swift 5.10+, pure SwiftPM layout, documented like production software from day one.

---

## Repository Layout Essentials

### Source Code
- `Sources/TOONCore` – Zero-dependency lexer, parser, serializer, error taxonomy
- `Sources/TOONCodable` – Swift Codable integration, ToonEncoder/ToonDecoder, schema priming
- `Sources/TOONCLI` – CLI tool (`toon-swift`) for encode/decode/validate/stats
- `Sources/TOONBenchmarks` – Performance benchmarks and profiling harness
- `Tests/` – Matching test targets with comprehensive coverage (≥99% line / ≥97% branch)

### Documentation Structure
**All documentation lives in `docs/` with strict organization:**

- **`docs/agents.md`** – **(THIS FILE)** Canonical AI agent instructions
  - **Source of truth** for all agent contexts
  - **Symlinked to:**
    - `AGENTS.md` (root) → for general visibility
    - `CLAUDE.md` (root) → for Claude-specific tools
    - `.github/copilot-instructions.md` → for GitHub Copilot
  - **Never edit the symlinks** - always edit `docs/agents.md`

- **`docs/plans/`** – Active implementation plans (update frequently)
  - `plan.md` – **Master roadmap** with all stages (0-11+), current status, detailed execution plans

- **`docs/reference/`** – Stable reference documents (update rarely)
  - `contributing.md` – Contribution guidelines
  - `release-checklist.md` – Release process steps
  - `spec-alignment.md` – TOON spec compliance report
  - `spec-version.md` – Tracked spec version
  - `tutorials-checklist.md` – DocC tutorial status (all complete)
  - `perf-visualization-options.md` – Performance dashboard design notes
  - `remaining-work-summary.md` – High-level work summary (update after major milestones)

- **`docs/sessions/`** – Historical session logs (archive after completion)
  - Date-stamped session summaries (YYYY-MM-DD format)
  - Benchmark results and optimization attempts
  - **Never delete** - provides context for decisions

- **`docs/releases/`** – Release summaries (one per version)
  - `vX.Y.Z-summary.md` format
  - Keep forever as historical record

- **`docs/DocC/`** – DocC tutorials (GettingStarted, TabularArrays, SchemaPriming)

### Temporary Files Directory
- **`tmp/`** – **⚠️ CRITICAL: ALL TEMPORARY FILES GO HERE**
  - **Purpose:** Profiling traces, benchmark logs, debug output, temporary scripts, working files
  - **Git-ignored:** Never committed to repository
  - **Why here:** Avoids system temp directory permission issues
  - **Clean regularly:** Nothing here should be permanent
  - **Common uses:**
    - `.trace` files from Instruments profiling
    - Benchmark working data (`tmp/results/`)
    - Build logs and diagnostic output
    - Temporary test files
    - Debugging artifacts
  - **Example commands:**
    ```bash
    # Profiling
    instruments -t "Time Profiler" -D tmp/encode.trace ...
    
    # Benchmarks
    swift run TOONBenchmarks --format json --output tmp/results.json
    
    # Cleanup when needed
    rm -rf tmp/*
    ```

### Other Critical Directories
- `reference/` – Upstream `toon-format/toon` checkout. **Never edit**; only pull updates
- `reference/spec` – Spec fixtures synced via `Scripts/update-fixtures.swift`
- `README.md` – Public project page; keep badges accurate with CI
- `CHANGELOG.md` – Release history (Keep a Changelog format)
- `.github/workflows/` – CI pipelines (ci.yml, coverage.yml, performance-benchmarks.yml)

### Documentation Rules
1. **`docs/agents.md`** = canonical source, symlinked to root (AGENTS.md, CLAUDE.md, .github/copilot-instructions.md)
2. **Plans folder** = active work, update frequently, single source of truth (`plan.md`)
3. **Reference folder** = stable info, update rarely, comprehensive
4. **Sessions folder** = historical archive, **never delete**, date-stamped (YYYY-MM-DD format)
5. **All filenames** = lowercase-with-hyphens (e.g., `spec-alignment.md`)
6. **No markdown in project root** except README.md and CHANGELOG.md (others are symlinks)
7. **Temporary files** = `tmp/` directory only, never use system temp

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
9. **Plan + commit hygiene** – Break every substantial task into discrete steps (update `docs/plan.md`, including the Performance Tracking Playbook, when plans change) and write descriptive commits that describe *why* and *what* (e.g., `perf: add compare script`, not `update file`). Use `gh-commit-watch` for every commit/push so CI is monitored asynchronously:
   - `gh-commit-watch -m "message" -w "ci|Performance Benchmarks|Publish Performance History|Coverage Badge"` stages all changes, commits, pushes, and spawns a tmux session to tail CI (including perf + coverage publishers). Detach immediately (`Ctrl-b d`) so work can continue.
   - At the start of every new task, reattach (`tmux attach -t <session>`) or run `gh run list` to confirm previous workflows finished. If any failed, fix them before continuing.
   - The default workflow filter is `ci`—pass a comma/pipe list if perf/history runs are relevant to the change.
10. **Schema priming awareness** – When touching encoder/decoder logic, consider whether `ToonSchema` hints (validation + serializer fast paths) need updates. Every new structural feature must have schema-backed tests plus README/DocC coverage.

## Autonomous Execution

- Treat `docs/plan.md` as the authoritative queue: follow the next pending stage automatically, update this plan (and `docs/performance-tracking.md` when applicable) as you complete pieces, and never stop after a task waiting for "what now?" prompts. If the plan is unclear, pick the next logical item yourself, execute it, and record the decision so reviewers see the new status (no further human direction required for staging).

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
   - Performance work must also refresh the Performance Tracking Playbook inside `docs/plan.md` (plan + checklist) so contributors always know the current process.
   - For releases, rerun `Scripts/check-spec-alignment.swift`, refresh `docs/spec-alignment.md`, update `CHANGELOG.md`, and follow the release checklist in [`docs/plan.md#release-checklist`](docs/plan.md#release-checklist).
7. **Final response**
   - Inline file references (path:line) for modifications.
   - Mention tests/benchmarks run; if skipped, explain why.

## Commit & Push Discipline

- **Commit after every logical change:** After implementing code, docs, tests, or benchmarks, create a descriptive commit that explains the change’s purpose (e.g., `perf: reuse parser buffers`), even if multiple files were touched.
- **Push immediately:** Push the commit before starting another task so the release/perf histories stay synchronized and CI/workflows (perf/coverage) can pick up the new artifacts.
- **Use `gh-commit-watch`:** Run `gh-commit-watch -w perf|coverage|ci` after pushing to monitor the automated workflows related to perf, coverage, and CI.

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
- Read the [Performance Tracking Playbook](docs/plan.md#performance-tracking-playbook) for the end-to-end telemetry/graph plan (history JSON, Shields endpoint, README badge expectations).
- Local perf workflow (run before pushing perf-sensitive changes):
  1. `swift run TOONBenchmarks --format json --output Benchmarks/results/latest.json`
  2. `swift Scripts/compare-benchmarks.swift Benchmarks/results/latest.json Benchmarks/baseline_reference.json --tolerance 0.05`
- **Coverage workflow (Codecov replacement):**
  1. `swift test --enable-code-coverage --parallel`
  2. `PROFILE=$(find .build -path "*/codecov/default.profdata" -print -quit)` (`exit 1` if empty).
  3. `swift Scripts/coverage-badge.swift --profile "$PROFILE" --binary-root .build --output coverage-artifacts --label coverage`
  4. Inspect `coverage-artifacts/coverage-summary.json` (line/function/region %). Delete the directory before committing.
  5. Run `swift Scripts/check-coverage.swift --profile "$PROFILE" --binary-root .build --check "Sources/TOONCore:99:97" --check "Sources/TOONCodable:99:97"` locally when touching core code to confirm thresholds. CI runs the same script after tests.
  6. `coverage.yml` runs automatically on `main`, pushing `coverage-badge.json` + `coverage-summary.json` to `gh-pages/coverage/`. Treat failures the same as CI/perf.
- Use `gh` freely for repo inspection: e.g. `gh run list`, `gh run view <id> --log`, `gh issue status`, etc., to diagnose CI failures or workflow status quickly. Capture relevant snippets in final summaries when the CLI output explains a fix (include the `Coverage Badge` workflow in every check).

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

- `toon-swift` should mirror TypeScript CLI flags: `encode`, `decode`, `validate`, `stats`, `--delimiter`, `--indent`, `--lenient`, `--strict`.
- Provide piping support (stdin/stdout) and file arguments.
- `--stats` prints JSON summary (bytes saved, token estimates from heuristics).
- Document CLI usage in README with examples; add snapshot tests for output.
- Encode/decode/stats/validate/bench already ship. Any new features must include integration tests, snapshots when output stabilizes, and should remain sanitizer-clean (CI now runs AddressSanitizer + ThreadSanitizer jobs).

---

## Documentation

- README badges (CI, coverage, Swift version, platforms, spec) must stay accurate; update URLs if org/project changes.
- DocC tutorials: “Getting started”, “Tabular arrays”, “Schema priming”.
- `docs/plan.md` is authoritative for roadmap; update when scope changes or stages complete.
- Add `CHANGELOG.md` before first release; follow Keep a Changelog format.

---

## Sync Strategy for Agent Files

- `docs/reference/agents.md` is the canonical source.
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
