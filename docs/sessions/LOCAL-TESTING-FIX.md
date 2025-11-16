# Fix Local Testing - Swift 6.2 XCTest Issue

## Problem
Swift 6.2 Command Line Tools doesn't include XCTest.framework, causing all tests to fail with:
```
error: no such module 'XCTest'
```

## Solution
Switch xcode-select to use full Xcode installation:

```bash
sudo xcode-select --switch /Applications/Xcode_26.0.1.app/Contents/Developer
```

(Requires sudo password)

## Verify
```bash
xcode-select -p
# Should show: /Applications/Xcode_26.0.1.app/Contents/Developer

swift test --filter JSONTextParserComprehensiveTests
# Should compile and run tests
```

## Revert (if needed)
```bash
sudo xcode-select --switch /Library/Developer/CommandLineTools
```

---

**Status:** Pending - requires sudo password input
**Note:** CI uses Swift 5.10 and works fine without this fix
