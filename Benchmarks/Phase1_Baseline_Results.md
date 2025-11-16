# Phase 1: Performance Baseline Results

**Date**: 2025-01-16  
**Dataset**: `users_10k.json` (10,000 user records, 2.0 MB JSON → 1.4 MB TOON)  
**Build**: Swift 5.10, Release mode (`-c release`)

## Results Summary

| Implementation | Encode (MB/s) | Decode (MB/s) |
|---------------|---------------|---------------|
| TypeScript    | 16.0          | 11.0          |
| Swift         | 3.6           | 9.2           |
| **Ratio**     | **0.22x**     | **0.83x**     |

## Analysis

Swift is currently **slower** than the TypeScript reference implementation:

- **Encode**: 4.5x slower than TypeScript (22% of TS speed)
- **Decode**: 1.2x slower than TypeScript (83% of TS speed)

## Timing Details

### Swift (average of 3 runs)
- Encode: 0.544s per run (1.632s total / 3)
- Decode: 0.156s per run (0.469s total / 3)

### File Sizes
- Input JSON: 1.96 MB
- Output TOON: 1.44 MB  
- Compression: 26.5% size reduction

## Issues Fixed

During benchmarking, discovered and fixed a bug where the `@` symbol in email addresses caused decoder crashes. The lexer's `isIdentifierContinuation` now allows `@` per TOON spec §7.2 (unquoted strings can contain most characters except the forbidden list).

**Fix**: `Sources/TOONCore/Lexer.swift:356` - Added `|| byte == UInt8(ascii: "@")` to identifier continuation check.

## Next Steps (Phase 2)

Performance optimization targets:
1. Profile encode path to find hotspots (likely string allocation/copying)
2. Profile decode path (smaller gap, but still room for improvement)
3. Implement buffer reuse and reduce allocations
4. Consider unsafe pointer optimizations for tight loops
5. Benchmark after each optimization to track progress

**Goal**: Match or exceed TypeScript performance (1.0x+ ratio) for both operations.
