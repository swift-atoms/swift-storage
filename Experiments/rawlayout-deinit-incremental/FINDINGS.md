# @_rawLayout Deinit Bug Investigation

<!--
---
version: 1.0.0
last_updated: 2026-02-05
status: IN_PROGRESS
---
-->

## Context

`Storage<Element>.Inline<capacity>` is a `~Copyable` struct containing a `@_rawLayout` field. When used from test targets or executables, its `deinit` is **not being called**, causing memory leaks.

## Question

Why does `Storage.Inline.deinit` not run for the real `swift-storage-primitives` package, but identical reimplementations in this experiment DO work?

## Key Finding

**This is a compiler bug.** The deinit code is never executed, not even when the struct is contained in a wrapper whose deinit IS called.

### Evidence

1. Added `fatalError()` and `print()` to Storage.Inline.deinit - neither triggered
2. Wrapper struct containing Storage.Inline has its deinit called, but Storage.Inline.deinit is skipped
3. Identical reimplementations in this experiment package work correctly

## Experiments Conducted

| Variant | Description | Result |
|---------|-------------|--------|
| Variant 1 | Single module baseline | PASS |
| Variant 2 | Module split with public import | PASS |
| Variant 3 | Full SwiftSettings | PASS |
| Variant 4 | Complex Initialization type | PASS |
| Variant 5 | Multi-module import graph | PASS |
| Variant 6 | External Index_Primitives dependency | PASS |
| RealPackageTest | Uses actual swift-storage-primitives | **FAIL** |
| CoreOnlyTest | Core-only, wrapper struct | Wrapper deinit PASS, Storage.Inline deinit **FAIL** |

## Reproduction Steps

```bash
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives/Experiments/rawlayout-deinit-incremental
swift run RealPackageTest
```

Expected output:
```
Starting test...
Before scope exit: Marker.instanceCount = 2
After scope exit: Marker.instanceCount = 0
SUCCESS: Storage.Inline.deinit was called!
```

Actual output:
```
Starting test...
Before scope exit: Marker.instanceCount = 2
After scope exit: Marker.instanceCount = 2
FAILURE: Storage.Inline.deinit was NOT called! instanceCount = 2
```

## Analysis

### What Works

The reimplementations (Variants 1-6) all work because they:
- Define everything in a single package
- Are compiled together with the test code

### What Doesn't Work

The real `swift-storage-primitives` package fails because:
- The type is defined in a separate, pre-compiled package
- Something about cross-package @_rawLayout deinit handling is broken

### Hypothesis

The bug appears to be related to how the Swift compiler handles deinit generation for `@_rawLayout` types when:
1. The type is defined in a dependency package (not the current package)
2. The type is used from a separate compilation unit

This may be a SIL generation issue or a linker symbol resolution issue where the deinit symbol from the dependency isn't being correctly linked/called.

## Next Steps

1. File a Swift bug report with this minimal reproduction
2. Check if there's a workaround (e.g., marking deinit differently)
3. Consider implementing a manual deinitialize pattern where callers must explicitly call cleanup

## Workaround (Temporary)

Until the bug is fixed, callers MUST manually call `deinitialize()` before the storage goes out of scope:

```swift
var storage = Storage<Element>.Inline<N>()
// ... use storage ...
storage.deinitialize()  // REQUIRED - deinit is broken
// storage goes out of scope
```

## Toolchain

- Swift 6.2 (Xcode 26)
- macOS 26 (arm64)
- Date: 2026-02-05
