// MARK: - @_rawLayout with ~Copyable Elements
// Purpose: Validate whether @_rawLayout(likeArrayOf:count:) supports ~Copyable elements
// Hypothesis: @_rawLayout requires Copyable elements (will fail to compile)
//
// Toolchain: Swift 6.2
// Platform: macOS 26
//
// Result: [PENDING]
// Date: 2026-02-05

import Index_Primitives

// MARK: - Variant 1: @_rawLayout with Copyable element (baseline)

struct CopyableInline<let capacity: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: capacity)
    struct _Raw: ~Copyable {}

    var _storage: _Raw

    init() { _storage = _Raw() }
}

// MARK: - Variant 2: @_rawLayout with ~Copyable element directly

struct NonCopyableElement: ~Copyable {
    var value: Int
}

struct NonCopyableInline<let capacity: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: NonCopyableElement, count: capacity)
    struct _Raw: ~Copyable {}

    var _storage: _Raw

    init() { _storage = _Raw() }
}

// MARK: - Variant 3: Generic outer STRUCT with ~Copyable constraint

struct GenericOuter<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() { _storage = _Raw() }
    }
}

// MARK: - Variant 3b: Generic outer ENUM with ~Copyable constraint

enum GenericEnumOuter<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() { _storage = _Raw() }
    }
}

// MARK: - Variant 4: Generic outer constrained to Copyable only

struct CopyableOuter<Element: Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() { _storage = _Raw() }
    }
}

// MARK: - Variant 5: Conditional extension approach

enum Storage<Element: ~Copyable> {}

extension Storage where Element: Copyable {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() { _storage = _Raw() }
    }
}

// MARK: - Variant 6: Full replica of main codebase structure

public enum FullStorage<Element: ~Copyable> {
    // Other nested types first (like Initialization, Heap in main codebase)
    public enum Initialization: Sendable, Equatable {
        case empty
        case one(Swift.Range<Index<Element>>)
        case two(first: Swift.Range<Index<Element>>, second: Swift.Range<Index<Element>>)
    }

    public final class Heap: ManagedBuffer<Int, Element> {}

    // Then Inline with @_rawLayout
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
        package var _initialization: FullStorage<Element>.Initialization

        @inlinable
        public init() {
            _storage = _Raw()
            _initialization = .empty
        }
    }
}

// MARK: - Variant 7: Test extension with redundant ~Copyable constraint
// This matches what the main codebase has that might cause issues

extension FullStorage.Initialization where Element: ~Copyable {
    var test: Bool { true }
}

// MARK: - Test instantiation

let v1 = CopyableInline<4>()
let v2 = NonCopyableInline<4>()
let v3 = GenericOuter<Int>.Inline<4>()
let v4 = CopyableOuter<Int>.Inline<4>()
let v5 = Storage<Int>.Inline<4>()

// Test with ~Copyable element
let v3nc = GenericOuter<NonCopyableElement>.Inline<4>()

// Test enum variants
let v3bInt = GenericEnumOuter<Int>.Inline<4>()
let v3bNc = GenericEnumOuter<NonCopyableElement>.Inline<4>()

// Test full replica
let v6Int = FullStorage<Int>.Inline<4>()
let v6Nc = FullStorage<NonCopyableElement>.Inline<4>()

print("V1 (Copyable concrete): OK")
print("V2 (NonCopyable concrete): OK")
print("V3 (GenericOuter<Int>.Inline): OK")
print("V4 (CopyableOuter<Int>.Inline): OK")
print("V5 (Storage<Int>.Inline): OK")
print("V3nc (GenericOuter<NonCopyableElement>.Inline): OK")
print("V3b-Int (GenericEnumOuter<Int>.Inline): OK")
print("V3b-NC (GenericEnumOuter<NonCopyableElement>.Inline): OK")
print("V6-Int (FullStorage<Int>.Inline): OK")
print("V6-NC (FullStorage<NonCopyableElement>.Inline): OK")
