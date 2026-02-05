// MARK: - @_rawLayout Deinit Investigation
// Purpose: Investigate why Swift doesn't call deinit for structs containing @_rawLayout fields
// Hypothesis: One of these factors prevents deinit: @_rawLayout, nesting, generic enum, or their combination
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: PENDING
// Date: 2026-02-05

import Synchronization

// ============================================================================
// MARK: - Deinit Tracking Infrastructure
// ============================================================================

final class DeinitTracker: @unchecked Sendable {
    let _count = Atomic<Int>(0)
    var count: Int { _count.load(ordering: .relaxed) }
    func increment() { _count.wrappingAdd(1, ordering: .relaxed) }
    func reset() { _count.store(0, ordering: .relaxed) }
}

let tracker = DeinitTracker()

// ============================================================================
// MARK: - Variant 1: Simple ~Copyable struct with deinit (BASELINE)
// Hypothesis: Basic ~Copyable deinit works
// Result: PENDING
// ============================================================================

struct SimpleNoncopyable: ~Copyable {
    let id: Int

    init(id: Int) { self.id = id }

    deinit {
        tracker.increment()
    }
}

func testVariant1() {
    print("=== Variant 1: Simple ~Copyable struct with deinit ===")
    tracker.reset()

    do {
        let s = SimpleNoncopyable(id: 1)
        _ = s.id
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 2: ~Copyable struct with @_rawLayout field
// Hypothesis: @_rawLayout field blocks deinit
// Result: PENDING
// ============================================================================

struct WithRawLayout: ~Copyable {
    @_rawLayout(likeArrayOf: Int, count: 3)
    struct _Raw: ~Copyable {}

    var _storage: _Raw
    let id: Int

    init(id: Int) {
        self._storage = _Raw()
        self.id = id
    }

    deinit {
        tracker.increment()
    }
}

func testVariant2() {
    print("=== Variant 2: ~Copyable struct with @_rawLayout field ===")
    tracker.reset()

    do {
        let s = WithRawLayout(id: 2)
        _ = s.id
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 3: Nested struct inside non-generic enum
// Hypothesis: Nesting in enum doesn't block deinit
// Result: PENDING
// ============================================================================

enum Container {
    struct Nested: ~Copyable {
        let id: Int

        init(id: Int) { self.id = id }

        deinit {
            tracker.increment()
        }
    }
}

func testVariant3() {
    print("=== Variant 3: Nested struct inside non-generic enum ===")
    tracker.reset()

    do {
        let s = Container.Nested(id: 3)
        _ = s.id
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 4: Nested struct inside generic enum
// Hypothesis: Generic enum doesn't block deinit
// Result: PENDING
// ============================================================================

enum GenericContainer<Element: ~Copyable> {
    struct Nested: ~Copyable {
        let id: Int

        init(id: Int) { self.id = id }

        deinit {
            tracker.increment()
        }
    }
}

func testVariant4() {
    print("=== Variant 4: Nested struct inside generic enum ===")
    tracker.reset()

    do {
        let s = GenericContainer<Int>.Nested(id: 4)
        _ = s.id
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 5: Nested struct with @_rawLayout inside generic enum
// Hypothesis: This combination blocks deinit (reproduces Storage.Inline)
// Result: PENDING
// ============================================================================

enum Storage<Element: ~Copyable> {
    struct Inline: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: 3)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() {
            self._storage = _Raw()
        }

        deinit {
            tracker.increment()
        }
    }
}

func testVariant5() {
    print("=== Variant 5: Nested @_rawLayout struct inside generic enum ===")
    tracker.reset()

    do {
        let s = Storage<Int>.Inline()
        _ = s
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 6: Nested struct with value generic parameter
// Hypothesis: Value generic (let capacity: Int) might affect deinit
// Result: PENDING
// ============================================================================

enum StorageWithCapacity<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() {
            self._storage = _Raw()
        }

        deinit {
            tracker.increment()
        }
    }
}

func testVariant6() {
    print("=== Variant 6: With value generic parameter (let capacity: Int) ===")
    tracker.reset()

    do {
        let s = StorageWithCapacity<Int>.Inline<3>()
        _ = s
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 7: @_rawLayout with Element in layout, no nesting
// Hypothesis: Using Element in @_rawLayout might be the issue
// Result: PENDING
// ============================================================================

struct DirectRawLayoutGeneric<Element: ~Copyable>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: 3)
    struct _Raw: ~Copyable {}

    var _storage: _Raw

    init() {
        self._storage = _Raw()
    }

    deinit {
        tracker.increment()
    }
}

func testVariant7() {
    print("=== Variant 7: @_rawLayout with Element, no nesting ===")
    tracker.reset()

    do {
        let s = DirectRawLayoutGeneric<Int>()
        _ = s
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 8: Wrapper struct consuming Storage (mirrors Vector.Inline)
// Hypothesis: Wrapper consuming storage might prevent Storage's deinit
// Result: PENDING
// ============================================================================

enum Storage8<Element: ~Copyable> {
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        struct _Raw: ~Copyable {}

        var _storage: _Raw

        init() {
            self._storage = _Raw()
        }

        deinit {
            tracker.increment()
        }
    }
}

// Wrapper that consumes Storage.Inline (like Vector.Inline)
enum Vector8<Element: ~Copyable, let N: Int> {
    struct Inline: ~Copyable {
        var _storage: Storage8<Element>.Inline<N>

        init(_storage: consuming Storage8<Element>.Inline<N>) {
            self._storage = _storage
        }
    }
}

func testVariant8() {
    print("=== Variant 8: Wrapper consuming Storage (mirrors Vector.Inline) ===")
    tracker.reset()

    do {
        let storage = Storage8<Int>.Inline<3>()
        let v = Vector8<Int, 3>.Inline(_storage: storage)
        _ = v
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 9: Wrapper with initializing closure (exact Vector.Inline pattern)
// Hypothesis: The closure-based init pattern might prevent deinit
// Result: PENDING
// ============================================================================

extension Vector8.Inline where Element: ~Copyable {
    init(initializing initializer: (UnsafeMutableRawPointer) -> Void) {
        var storage = Storage8<Element>.Inline<N>()
        unsafe withUnsafeMutablePointer(to: &storage._storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            unsafe initializer(raw)
        }
        self.init(_storage: storage)
    }
}

func testVariant9() {
    print("=== Variant 9: Wrapper with initializing closure ===")
    tracker.reset()

    do {
        let v = unsafe Vector8<Int, 3>.Inline(initializing: { ptr in
            unsafe ptr.assumingMemoryBound(to: Int.self).initialize(to: 42)
            unsafe (ptr + MemoryLayout<Int>.stride).assumingMemoryBound(to: Int.self).initialize(to: 43)
            unsafe (ptr + 2 * MemoryLayout<Int>.stride).assumingMemoryBound(to: Int.self).initialize(to: 44)
        })
        _ = v
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 10: Cross-module simulation (import simulation)
// Hypothesis: deinit not being exported properly across modules
// Result: PENDING
// ============================================================================

// Simulating cross-module by using @usableFromInline package access level

@usableFromInline
enum Storage10<Element: ~Copyable> {
    @usableFromInline
    struct Inline<let capacity: Int>: ~Copyable {
        @_rawLayout(likeArrayOf: Element, count: capacity)
        @usableFromInline
        package struct _Raw: ~Copyable {
            @usableFromInline
            init() {}
        }

        @usableFromInline
        package var _storage: _Raw

        @usableFromInline
        package var _count: Int

        @inlinable
        public init() {
            _storage = _Raw()
            _count = 0
        }

        deinit {
            print("Storage10.Inline deinit (count=\(_count))")
            tracker.increment()
        }
    }
}

@usableFromInline
enum Vector10<Element: ~Copyable, let N: Int> {
    @usableFromInline
    struct Inline: ~Copyable {
        @usableFromInline
        package var _storage: Storage10<Element>.Inline<N>

        @usableFromInline
        package init(_storage: consuming Storage10<Element>.Inline<N>) {
            self._storage = _storage
        }
    }
}

extension Vector10.Inline where Element: ~Copyable {
    @inlinable
    init(initializing initializer: (UnsafeMutableRawPointer) -> Void) {
        var storage = Storage10<Element>.Inline<N>()
        unsafe withUnsafeMutablePointer(to: &storage._storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            unsafe initializer(raw)
        }
        storage._count = N
        self.init(_storage: storage)
    }
}

func testVariant10() {
    print("=== Variant 10: Cross-module simulation (usableFromInline) ===")
    tracker.reset()

    do {
        let v = unsafe Vector10<Int, 3>.Inline(initializing: { ptr in
            unsafe ptr.assumingMemoryBound(to: Int.self).initialize(to: 42)
            unsafe (ptr + MemoryLayout<Int>.stride).assumingMemoryBound(to: Int.self).initialize(to: 43)
            unsafe (ptr + 2 * MemoryLayout<Int>.stride).assumingMemoryBound(to: Int.self).initialize(to: 44)
        })
        _ = v
    }

    let result = tracker.count == 1
    print("Deinit called: \(tracker.count) time(s)")
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Variant 11: Generic TrackedValue to match test
// Hypothesis: The ~Copyable Element type affects deinit behavior
// Result: PENDING
// ============================================================================

struct TrackedValue: ~Copyable {
    let value: Int
    let tracker: DeinitTracker

    init(_ value: Int, tracker: DeinitTracker) {
        self.value = value
        self.tracker = tracker
    }

    deinit {
        tracker.increment()
    }
}

func testVariant11() {
    print("=== Variant 11: With TrackedValue (exactly like test) ===")
    let tracker2 = DeinitTracker()

    do {
        var storage = Storage10<TrackedValue>.Inline<3>()
        unsafe withUnsafeMutablePointer(to: &storage._storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: TrackedValue.self)
            unsafe (ptr + 0).initialize(to: TrackedValue(1, tracker: tracker2))
            unsafe (ptr + 1).initialize(to: TrackedValue(2, tracker: tracker2))
            unsafe (ptr + 2).initialize(to: TrackedValue(3, tracker: tracker2))
        }
        storage._count = 3

        let v = Vector10<TrackedValue, 3>.Inline(_storage: storage)
        print("Created vector, TrackedValue deinit count: \(tracker2.count)")
        _ = v
    }

    print("After scope exit, TrackedValue deinit count: \(tracker2.count)")
    print("Storage.Inline deinit count (via global tracker): \(tracker.count)")
    let result = tracker2.count == 3
    print("Result: \(result ? "CONFIRMED" : "REFUTED")")
    print()
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("@_rawLayout Deinit Investigation")
print("=================================")
print()

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
testVariant8()
testVariant9()
testVariant10()
testVariant11()

print("=================================")
print("Summary:")
print("If all CONFIRMED: deinit works, issue is elsewhere")
print("If some REFUTED: those factors block deinit")
