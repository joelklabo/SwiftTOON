# Phase 2 Session 1: Initial Profiling Results

**Date**: 2025-01-16  
**Goal**: Identify and fix encode performance bottlenecks

## Failed Optimization Attempts

### Attempt 1: Indent Cache with Substring
**Theory**: Pre-allocate indent buffer, use `prefix()` to avoid repeated `String(repeating:)`  
**Result**: **49% SLOWER** (0.812s vs 0.544s baseline)  
**Why**: Substring creation overhead exceeded allocation savings

### Attempt 2: Pre-computed Indent Array
**Theory**: Cache array of pre-computed indent strings  
**Result**: **46% SLOWER** (0.794s vs 0.544s baseline)  
**Why**: Array lookup + retain/release overhead exceeded benefits

### Attempt 3: StringBuilder for Final Join
**Theory**: Use pre-allocated buffer instead of `lines.joined(separator: "\n")`  
**Result**: **27% SLOWER** (0.689s vs 0.544s baseline)  
**Why**: Still building intermediate array of lines first

## Key Insights

1. **String operations are highly optimized in Swift** - naive "optimizations" often make things worse
2. **The real bottleneck is architectural**: Building an array of string lines, then joining them
3. **TypeScript must write directly to output** instead of building intermediate structures

## Root Cause Analysis

Looking at `ToonSerializer.swift`:
```swift
// Current architecture (lines 13-24):
public func serialize(jsonValue: JSONValue) -> String {
    let lines = renderer.render(...)  // Returns [String]
    return lines.joined(separator: "\n")
}
```

The `render()` function recursively builds arrays:
- Every object/array creates a new array
- Results are concatenated with `result += otherArray`
- Array reallocation happens repeatedly
- Finally, all lines are joined into one string

**Better approach**: Write directly to output buffer like TypeScript does.

## Profiling Challenges

- `sample` tool couldn't attach to short-lived processes
- Instruments requires GUI
- Need better profiling methodology

## Next Steps

### Strategy Change: Look at TypeScript Implementation

Instead of guessing, examine how the reference implementation achieves 16 MB/s:

1. Check `reference/packages/core/src/encoder.ts`
2. Understand their buffer/writer architecture  
3. Port the efficient approach to Swift

### Alternative: Use Instruments

```bash
# Create long-running workload
cat > .temp/profile_workload.sh << 'EOF'
for i in {1..1000}; do
  .build/release/toon-swift encode < Benchmarks/Datasets/users_10k.json > /dev/null
done
EOF

# Profile with Instruments
instruments -t "Time Profiler" -D .temp/encode.trace .temp/profile_workload.sh
# Open .temp/encode.trace in Instruments.app
```

### Micro-optimization Ideas (AFTER architectural fix)

Once we have the right architecture:
1. Reduce string interpolation in hot paths
2. Use `append()` instead of `+` for strings
3. Pre-allocate buffer capacity based on JSON size estimate
4. Consider unsafe pointers for zero-copy operations

## Conclusion

**Don't optimize prematurely!** The current implementation's architecture is the problem, not individual string operations. Need to study the reference implementation's approach before continuing.

**Time spent**: 2 hours  
**Performance gain**: None (learned what NOT to do)  
**Next session**: Analyze TypeScript encoder architecture
