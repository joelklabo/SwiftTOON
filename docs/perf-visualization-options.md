# Performance Visualization Options

## Current State
- Single stacked area chart with 7 series (3 throughput + 4 phase durations)
- Mixed units (MB/s and seconds) make it hard to read
- No separation between high-level metrics and internal diagnostics

## Metrics Available
1. **Throughput metrics** (MB/s):
   - `lexer_micro` - Raw lexing speed
   - `parser_micro` - Parsing speed
   - `decode_end_to_end` - Full decode pipeline

2. **Object processing** (obj/s):
   - `decode_objects_per_second` - Objects decoded per second

3. **Phase durations** (seconds):
   - `Parser.parse` - Total parse time
   - `Parser.parseObject` - Object parsing
   - `Parser.parseArrayValue` - Array value parsing
   - `Parser.parseListArray` - List array parsing
   - `Parser.buildValue` - Value building
   - `Parser.readRowValues` - Row value reading

---

## Option 1: Multi-Panel Dashboard (Recommended)

**Layout:** Three separate graphs stacked vertically in the README

### Panel A: Pipeline Throughput (Primary Metric)
```
Chart type: Line chart (not stacked)
Y-axis: MB/s
Series:
  - lexer_micro (blue)
  - parser_micro (orange) 
  - decode_end_to_end (green)
Title: "Throughput by Stage (MB/s)"
```

### Panel B: Parser Phase Breakdown (Diagnostic)
```
Chart type: Stacked area chart
Y-axis: Seconds (milliseconds for readability)
Series:
  - Parser.parseObject
  - Parser.parseArrayValue
  - Parser.parseListArray
  - Parser.buildValue
  - Parser.readRowValues
Title: "Parser Phase Durations (ms)"
```

### Panel C: Object Processing Rate
```
Chart type: Line chart
Y-axis: Objects/sec
Series:
  - decode_objects_per_second
Title: "Objects Decoded per Second"
```

**Pros:**
- Clear separation of concerns
- Each chart optimized for its data (no mixed units)
- Easy to spot regressions in specific areas
- Stacked area for phases shows total parse time + breakdown

**Cons:**
- Takes more README real estate
- Three separate workflow calls to QuickChart API

**Implementation:**
- Modify `Scripts/update-perf-artifacts.swift` to generate 3 PNGs
- Stack them in README with descriptive headers
- Add collapsible `<details>` section for diagnostic charts

---

## Option 2: Interactive HTML Dashboard (GitHub Pages)

**Layout:** Dedicated GitHub Pages site at `joelklabo.github.io/SwiftTOON/perf/`

### Features:
1. **Landing view:** All 3 charts from Option 1 on one page
2. **Zooming:** Click any point to see commit details
3. **Toggleable series:** Click legend to hide/show series
4. **Comparison mode:** Select two commits to diff metrics
5. **Raw data table:** Show JSON history in sortable table
6. **Sparklines in README:** Small inline trend indicators replacing current badge

**Technology:**
- Static HTML + Chart.js or D3.js
- Consume `perf-history.json` directly via fetch
- No server required (100% GitHub Pages)

**README Integration:**
```markdown
## Performance Tracking

📊 **[View Interactive Dashboard](https://joelklabo.github.io/SwiftTOON/perf/)**

**Quick Stats:**
- Decode: 3.75 MB/s ![trend](sparkline-decode.svg)
- Parse: 2.59 MB/s ![trend](sparkline-parse.svg)
- Lexer: 5.34 MB/s ![trend](sparkline-lexer.svg)
```

**Pros:**
- Professional, modern UX
- No README bloat (just link)
- Can add features over time without README changes
- Supports deep analysis (regression bisection, etc.)

**Cons:**
- Requires building HTML/JS artifacts
- Users must click through to see details
- More complex CI pipeline

**Implementation:**
- Create `docs/perf-dashboard/` with index.html template
- `perf-history.yml` copies template + data to gh-pages
- Generate sparkline SVGs for README quick stats

---

## Option 3: Compact Composite Chart (Minimal)

**Layout:** Single chart with dual Y-axes and clear visual separation

### Chart Design:
```
Left Y-axis: Throughput (MB/s)
Right Y-axis: Phase Duration (ms)

Top half (solid lines):
  - lexer_micro (blue)
  - parser_micro (orange)
  - decode_end_to_end (green)

Bottom half (dashed lines, faded):
  - Parser phase durations (stacked area, semi-transparent)

Separator line: Horizontal rule at midpoint
```

**Pros:**
- Single image (current README size)
- Shows relationship between throughput and phase timing
- Minimal CI complexity

**Cons:**
- Still mixing units (confusing at first glance)
- Harder to read specific values
- Limited by QuickChart API capabilities

**Implementation:**
- Update chart config to use dual Y-axes
- Add visual separator (annotation line)
- Style phase metrics as secondary (opacity, dashed)

---

## Recommendation: Option 1 (Multi-Panel Dashboard)

**Why:**
1. **Clearest communication:** Each stakeholder sees their metric
   - Users → "Is decode fast?" (Panel A)
   - Contributors → "Where's the bottleneck?" (Panel B)
   - Maintainers → "What's the throughput trend?" (Panel A + C)

2. **Future-proof:** Easy to add more metrics as panels
   - Encode throughput (when implemented)
   - Memory usage (future enhancement)
   - Allocations per operation (future enhancement)

3. **Low complexity:** Just 3 chart configs, same workflow

4. **README-native:** No clicking required, shows commitment to transparency

### Suggested README Structure:
```markdown
## Performance Tracking

### Pipeline Throughput
[Graph A - 1200x300px]

### Parser Phase Breakdown (Diagnostic)
<details>
<summary>View internal phase metrics</summary>

[Graph B - 1200x300px]

</details>

### Object Processing Rate
<details>
<summary>View objects/sec metric</summary>

[Graph C - 1200x300px]

</details>
```

---

## Implementation Checklist for Option 1

- [ ] Update `Scripts/update-perf-artifacts.swift`:
  - [ ] Add `generateThroughputChart()` → `perf-throughput.png`
  - [ ] Add `generatePhaseChart()` → `perf-phases.png`
  - [ ] Add `generateObjectsChart()` → `perf-objects.png`
  - [ ] Keep existing combined chart for backward compat

- [ ] Update `README.md`:
  - [ ] Add section headers for each chart
  - [ ] Wrap diagnostic charts in `<details>` blocks
  - [ ] Update cache-busting params (`?v=3`)

- [ ] Test locally:
  - [ ] Run benchmarks → `latest.json`
  - [ ] Generate artifacts with script
  - [ ] Verify 3 PNGs render correctly

- [ ] Update plan docs:
  - [ ] Document the new visualization strategy
  - [ ] Update Performance Tracking Playbook

---

## Future Enhancements (Any Option)

1. **Regression annotations:** Highlight commits where perf dropped >5%
2. **Target lines:** Show baseline/goal as horizontal reference
3. **Comparison view:** Side-by-side before/after for PRs
4. **Historical metrics:** Add memory/allocations when instrumentation lands
5. **Export capability:** Download CSV/JSON from dashboard for analysis
