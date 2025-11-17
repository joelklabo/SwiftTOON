# Stage 11 Phase 2-3: Performance Recovery Complete

**Date:** 2025-11-16  
**Status:** ✅ COMPLETE - Exceeded all targets

## Results

### Performance Improvements vs Old Baseline
- **Lexer:** 4.50 → 26.83 MB/s (+495.7%)
- **Parser:** 2.94 → 5.83 MB/s (+98.4%) - Target was 2.94 MB/s
- **Decoder:** 3.80 → 9.97 MB/s (+162.7%) - Target was 3.79 MB/s
- **Objects/s:** 414.6 → 1235.2 (+197.9%)

### What Happened

The "regression" we tracked was actually comparing against an outdated baseline from v0.1.1. 

Between v0.1.1 and now, **10 performance optimization commits** were made:

1. perf: publish phase metrics
2. perf: reserve JSONObject buffers
3. perf: inline newline handling for list items
4. perf: cache peek tokens
5. perf: shortcut single-token rows
6. perf: reserve list buffers
7. perf: shortcut inline scalars
8. perf: inline list parse
9. perf: trim buildValue allocation
10. perf: track buildValue and log iterations

These optimizations collectively produced **98% parser improvement** and **163% decoder improvement**.

## Phases Completed

- ✅ **Phase 1:** TypeScript baseline established
- ✅ **Phase 2:** Parser recovery (exceeded target by 98%)
- ✅ **Phase 3:** Decoder recovery (exceeded target by 163%)

## Next: Phase 4

**Schema-Primed Fast Path** - Demonstrate ≥20% speedup with schema hints vs default analyzer.

## Updated Baseline

Baseline updated to lock in these improvements:
- `Benchmarks/baseline_reference.json` now reflects current performance
- All benchmarks within ±20% tolerance ✅
