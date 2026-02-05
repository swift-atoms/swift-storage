# @_rawLayout Deinit Investigation Summary

**Date**: 2026-02-05
**Toolchain**: Swift 6.2 (Xcode 26)
**Platform**: macOS 26 (arm64)
**Status**: UNRESOLVED - Root cause not yet identified

## Problem Statement

`Storage<Element>.Inline<capacity>` is a `~Copyable` struct containing an `@_rawLayout` field. When used from test targets, its `deinit` is **not being called**, causing memory leaks of initialized elements.

## Observed Behavior

1. **Experiment (standalone executable)**: deinit works correctly ✓
2. **Cross-module experiment (library + executable)**: deinit works correctly ✓
3. **Cross-module experiment (library + test target)**: deinit works correctly ✓
4. **Real package test target**: deinit NOT called ✗

## Key Files

### Type Definition
`/Users/coen/Developer/swift-primitives/swift-storage-primitives/Sources/Storage Primitives Core/Storage.swift`

```swift
public enum Storage<Element: ~Copyable> {
    public struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline
            init() {}
        }

        @usableFromInline
        package var _storage: _Raw

        @usableFromInline
        package var _initialization: Initialization

        @inlinable
        public init() {
            _storage = _Raw()
            _initialization = .empty
        }

        deinit {
            self.deinitialize()
        }

        // ... deinitialize() methods
    }
}
```

### Failing Test
`/Users/coen/Developer/swift-primitives/swift-storage-primitives/Tests/Storage Inline Primitives Tests/Storage.Inline Tests.swift`

```swift
@Test
func `Storage_Inline own deinit runs`() {
    final class Marker: @unchecked Sendable {
        nonisolated(unsafe) static var instanceCount = 0
        init() { unsafe Marker.instanceCount += 1 }
        deinit { unsafe Marker.instanceCount -= 1 }
    }

    unsafe Marker.instanceCount = 0

    do {
        var storage = Storage<Marker>.Inline<2>()
        storage.initialize(to: Marker(), at: .zero)
        storage.initialize(to: Marker(), at: 1)
        storage.initialization = .linear(count: 2)

        unsafe #expect(Marker.instanceCount == 2)
        // storage goes out of scope, Storage.Inline.deinit should run
    }

    // FAILS: Marker.instanceCount is still 2, not 0
    unsafe #expect(Marker.instanceCount == 0)
}
```

### Working Experiment
`/Users/coen/Developer/swift-primitives/swift-storage-primitives/Experiments/rawlayout-deinit-crossmodule/`

This experiment has:
- `StorageLib` target with `@_rawLayout` type and deinit
- `StorageLibTests` test target that imports StorageLib
- **All tests pass** - deinit IS called

## Package Structure Comparison

### Working Experiment Structure
```
rawlayout-deinit-crossmodule/
├── Package.swift
├── Sources/
│   └── StorageLib/
│       └── Storage.swift  (type + deinit in same file)
└── Tests/
    └── StorageLibTests/
        └── DeinitTests.swift
```

### Real Package Structure (NOT working)
```
swift-storage-primitives/
├── Package.swift
├── Sources/
│   ├── Storage Primitives Core/
│   │   ├── Storage.swift  (type definition + deinit)
│   │   ├── Storage.Initialization.swift
│   │   └── Storage.Heap.Header.swift
│   ├── Storage Inline Primitives/
│   │   ├── Storage.Inline ~Copyable.swift  (extensions)
│   │   ├── Storage.Inline Copyable.swift
│   │   └── ...
│   └── ...
└── Tests/
    └── Storage Inline Primitives Tests/
        └── Storage.Inline Tests.swift
```

## Key Differences

1. **Module Split**: Real package has type in `Storage_Primitives_Core`, extensions in `Storage_Inline_Primitives`. Test imports `Storage_Inline_Primitives` which re-exports Core via `public import`.

2. **Dependencies**: Real package depends on `swift-index-primitives` for `Index<Element>` type used in `Initialization` enum.

3. **Initialization Tracking**: Real package uses `Initialization` enum (`.empty`, `.one(Range)`, `.two(Range, Range)`). Experiment uses simple `Int` count.

## What We've Verified

1. **Not a test target issue** - Experiment test target works
2. **Not a cross-module issue** - Experiment cross-module works
3. **Not an @_rawLayout issue** - Experiment uses same attribute and works
4. **Not a ~Copyable issue** - Experiment uses same constraint and works
5. **Print statements in deinit don't appear** - Deinit truly not being called
6. **Adding fatalError to deinit doesn't crash** - Deinit code not executed

## Hypotheses to Investigate

1. **Module re-export issue**: Something about `public import Storage_Primitives_Core` in the extension module might affect symbol resolution for deinit.

2. **Generic type complexity**: The real `Initialization` enum uses `Range<Index<Element>>` from external package, vs simple `Int` in experiment.

3. **Build configuration**: Real package has more complex Package.swift with multiple targets and dependencies.

4. **Inlining/optimization**: `@inlinable` on init but not deinit might cause issues.

5. **Access level interaction**: Mix of `public`, `package`, `@usableFromInline` might affect deinit visibility.

## Commands to Reproduce

```bash
# Run failing test
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives
swift test --filter "Storage_Inline own deinit"

# Run working experiment
cd /Users/coen/Developer/swift-primitives/swift-storage-primitives/Experiments/rawlayout-deinit-crossmodule
swift test
```

## Next Steps

1. Create a minimal reproducer that FAILS by incrementally adding complexity to the working experiment until it breaks
2. Check if the issue is specific to the `Initialization` enum or `Index<Element>` dependency
3. Try moving deinit to extension module instead of core module
4. Check SIL/IR output to see if deinit is being generated at all
