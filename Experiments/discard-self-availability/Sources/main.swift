// MARK: - Discard Self Availability - Extended Investigation
// Purpose: Explore `discard self` limitations and potential workarounds for Storage.Inline
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (feature works) but NOT VIABLE for Storage.Inline
// Date: 2026-02-05
//
// KEY FINDINGS:
// 1. `discard self` ONLY works with trivially-destructible stored properties
// 2. @_rawLayout types are NOT trivially destructible (even without deinit)
// 3. Reference types (AnyObject?, closures) are NOT trivially destructible
// 4. Tuples/InlineArray of trivial types ARE trivially destructible
// 5. Can store ~Copyable elements in tuple storage, but deinit can't clean them up
//    without a type-aware deinitializer (which would break trivial destructibility)
//
// CONCLUSION: `discard self` cannot be used with Storage.Inline because:
// - Storage.Inline uses @_rawLayout (not trivially destructible)
// - Alternative: tuple storage can use discard, but leaks in deinit
// - No way to store a generic deinitializer without breaking trivial destructibility
//
// RECOMMENDATION: Use Option E + I from research (package-internal deinitialize)

// MARK: - Variant 1: Basic discard (trivial properties)
// Hypothesis: `discard self` works with trivially-destroyed properties
// Result: CONFIRMED

struct TrivialResource: ~Copyable {
    var value: Int = 42

    consuming func cleanup() {
        print("TrivialResource cleanup: \(value)")
        discard self
    }

    deinit {
        print("TrivialResource deinit: \(value)")
    }
}

// MARK: - Variant 2: Discard with class property
// Hypothesis: `discard self` works even with class (reference) property
// Result: REFUTED - AnyObject? cannot be trivially destroyed (ARC)
// Error: "type 'AnyObject?' cannot be trivially destroyed"

// struct ResourceWithClass: ~Copyable {
//     var value: Int = 42
//     var ref: AnyObject? = nil  // <-- This fails!
//     consuming func cleanup() { discard self }
// }

// MARK: - Variant 3: Nested ~Copyable struct
// Hypothesis: `discard self` fails with nested ~Copyable that has deinit
// Result: TBD

struct Inner: ~Copyable {
    var x: Int = 0
    deinit { print("Inner deinit") }
}

struct OuterWithInner: ~Copyable {
    var inner: Inner

    init() { inner = Inner() }

    // This might fail - Inner has deinit, so not trivially destructible
    // consuming func cleanup() {
    //     discard self
    // }

    deinit {
        print("OuterWithInner deinit")
    }
}

// MARK: - Variant 4: @_rawLayout struct (no deinit)
// Hypothesis: @_rawLayout without deinit might be trivially destructible
// Result: REFUTED - @_rawLayout types cannot be trivially destroyed
// Error: "type 'RawLayoutWrapper<T, N>.Raw' cannot be trivially destroyed"
//
// This is the BLOCKER for Storage.Inline using discard self.

// struct RawLayoutWrapper<T, let N: Int>: ~Copyable {
//     @_rawLayout(likeArrayOf: T, count: N)
//     struct Raw: ~Copyable { init() {} }  // <-- This fails!
//     var raw: Raw
//     consuming func cleanup() { discard self }
// }

// MARK: - Variant 5: Separate cleanup via consume
// Hypothesis: Use `_ = consume self` pattern instead of discard
// Result: TBD

struct ConsumePattern: ~Copyable {
    var value: Int = 42

    consuming func cleanup() -> Int {
        let v = value
        print("ConsumePattern cleanup: \(v)")
        // Don't discard - just return and let caller handle
        return v
    }

    deinit {
        print("ConsumePattern deinit: \(value)")
    }
}

// MARK: - Variant 6: UnsafeMutablePointer approach
// Hypothesis: Store data in pointer, making struct trivially destructible
// Result: TBD

struct PointerBased<Element>: ~Copyable {
    // Raw pointer storage - trivially destructible!
    var ptr: UnsafeMutablePointer<Element>?
    var count: Int = 0

    init() { ptr = nil }

    mutating func allocate(capacity: Int) {
        ptr = .allocate(capacity: capacity)
    }

    consuming func cleanup() {
        if let p = ptr {
            p.deinitialize(count: count)
            p.deallocate()
        }
        print("PointerBased cleanup")
        discard self
    }

    deinit {
        if let p = ptr {
            p.deinitialize(count: count)
            p.deallocate()
        }
        print("PointerBased deinit")
    }
}

// MARK: - Variant 7: InlineArray storage
// Hypothesis: InlineArray<N, Int> might be trivially destructible
// Result: TBD

struct InlineArrayStorage<let N: Int>: ~Copyable {
    var storage: InlineArray<N, Int>
    var count: Int = 0

    init() {
        storage = InlineArray(repeating: 0)
    }

    consuming func cleanup() {
        print("InlineArrayStorage cleanup, count: \(count)")
        discard self
    }

    deinit {
        print("InlineArrayStorage deinit")
    }
}

// MARK: - Variant 8: Tuple storage (fixed size)
// Hypothesis: Tuple of trivial types is trivially destructible
// Result: TBD

struct TupleStorage: ~Copyable {
    var storage: (Int, Int, Int, Int) = (0, 0, 0, 0)
    var count: Int = 0

    consuming func cleanup() {
        print("TupleStorage cleanup, count: \(count)")
        discard self
    }

    deinit {
        print("TupleStorage deinit")
    }
}

// MARK: - Variant 9: Tuple-based raw storage for ~Copyable
// Hypothesis: Use tuple of UInt64 as raw bytes, access via pointer for ~Copyable
// NOTE: InlineArray won't work - it requires `repeating:` init which needs Copyable
// Result: TBD

// Fixed-size storage: 4 x UInt64 = 32 bytes
struct TupleBackedStorage: ~Copyable {
    // Tuple of trivial types - IS trivially destructible
    var storage: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    var initialized: Bool = false

    // Store a value (up to 32 bytes)
    mutating func initialize<T: ~Copyable>(to value: consuming T) {
        precondition(MemoryLayout<T>.size <= 32, "Element too large")
        // Get raw pointer to storage
        let storagePtr = unsafe withUnsafeMutablePointer(to: &storage) { $0 }
        let elementPtr = unsafe UnsafeMutableRawPointer(storagePtr)
            .assumingMemoryBound(to: T.self)
        unsafe elementPtr.initialize(to: value)
        initialized = true
    }

    // Retrieve and deinitialize the value
    mutating func take<T: ~Copyable>(as type: T.Type) -> T {
        precondition(initialized, "Not initialized")
        let result: T = unsafe withUnsafeMutablePointer(to: &storage) { storagePtr in
            let elementPtr = UnsafeMutableRawPointer(storagePtr)
                .assumingMemoryBound(to: T.self)
            return unsafe elementPtr.move()
        }
        initialized = false
        return result
    }

    // Deinitialize without returning
    mutating func deinitializeElement<T: ~Copyable>(as type: T.Type) {
        guard initialized else { return }
        unsafe withUnsafeMutablePointer(to: &storage) { storagePtr in
            let elementPtr = UnsafeMutableRawPointer(storagePtr)
                .assumingMemoryBound(to: T.self)
            unsafe elementPtr.deinitialize(count: 1)
        }
        initialized = false
    }

    consuming func cleanup<T: ~Copyable>(elementType: T.Type) {
        // Deinitialize element first
        if initialized {
            unsafe withUnsafeMutablePointer(to: &storage) { storagePtr in
                let elementPtr = UnsafeMutableRawPointer(storagePtr)
                    .assumingMemoryBound(to: T.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        print("TupleBackedStorage cleanup")
        // Now discard self - only trivial storage remains
        discard self
    }

    deinit {
        print("TupleBackedStorage deinit (initialized: \(initialized))")
        // WARNING: If initialized == true, we leak the element!
        // This is the trade-off for using discard.
    }
}

// Test with a ~Copyable element
struct TrackedElement: ~Copyable {
    var id: Int
    init(_ id: Int) {
        self.id = id
        print("TrackedElement init: \(id)")
    }
    deinit {
        print("TrackedElement deinit: \(id)")
    }
}

// MARK: - Main

print("=== Discard Self Extended Investigation ===")
print()

print("--- Variant 1: Trivial properties ---")
do {
    let r = TrivialResource(value: 100)
    r.cleanup()
    print("After cleanup (no deinit expected)")
}
print()

print("--- Variant 2: Class property (REFUTED - AnyObject not trivially destroyed) ---")
print()

print("--- Variant 3: Nested ~Copyable (skipped - compile error) ---")
print()

print("--- Variant 4: @_rawLayout wrapper (REFUTED - @_rawLayout not trivially destroyed) ---")
print()

print("--- Variant 5: Consume pattern ---")
do {
    let r = ConsumePattern(value: 500)
    let v = r.cleanup()
    print("Returned value: \(v)")
    print("After cleanup (deinit WILL run because no discard)")
}
print()

print("--- Variant 6: Pointer-based ---")
do {
    var r = PointerBased<Int>()
    r.allocate(capacity: 4)
    r.cleanup()
    print("After cleanup (no deinit expected)")
}
print()

print("--- Variant 7: InlineArray storage ---")
do {
    let r = InlineArrayStorage<4>()
    r.cleanup()
    print("After cleanup (no deinit expected)")
}
print()

print("--- Variant 8: Tuple storage ---")
do {
    let r = TupleStorage()
    r.cleanup()
    print("After cleanup (no deinit expected)")
}
print()

print("--- Variant 9: Tuple-backed ~Copyable storage ---")
do {
    var storage = TupleBackedStorage()
    storage.initialize(to: TrackedElement(999))
    print("Element stored")
    // Use cleanup with discard
    storage.cleanup(elementType: TrackedElement.self)
    print("After cleanup (TrackedElement should be deinitialized, no storage deinit)")
}
print()

print("--- Variant 9b: Tuple-backed without cleanup (leak test) ---")
do {
    var storage = TupleBackedStorage()
    storage.initialize(to: TrackedElement(888))
    print("Element stored, letting storage go out of scope WITHOUT cleanup")
    // Don't call cleanup - storage will deinit but element WON'T
}
print("After scope - TrackedElement 888 was LEAKED (no deinit)")
print()

// MARK: - Variant 10: Tuple storage with deinitializer function pointer
// Hypothesis: Store a closure/function pointer to handle deinit
// Result: TBD

// Type-erased deinitializer
typealias Deinitializer = @convention(c) (UnsafeMutableRawPointer) -> Void

struct SmartTupleStorage: ~Copyable {
    var storage: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    var deinitialize: Deinitializer? = nil
    var initialized: Bool = false

    mutating func store<T: ~Copyable>(_ value: consuming T) {
        precondition(MemoryLayout<T>.size <= 32)
        let storagePtr = unsafe withUnsafeMutablePointer(to: &storage) { $0 }
        let elementPtr = unsafe UnsafeMutableRawPointer(storagePtr)
            .assumingMemoryBound(to: T.self)
        unsafe elementPtr.initialize(to: value)

        // Store the deinitializer - but we can't capture T in @convention(c)
        // This approach won't work for generic T
        initialized = true
    }

    // The problem: we can't store a generic deinitializer as @convention(c)
    // And we can't use Swift closures because they're not trivially destructible (ARC)

    deinit {
        print("SmartTupleStorage deinit")
        // Can't call deinitialize without knowing T
    }
}

print("--- Variant 10: Function pointer approach ---")
print("BLOCKED: Can't store generic deinitializer as @convention(c)")
print("Swift closures are not trivially destructible (they use ARC)")
print()

print("=== Investigation Complete ===")

// MARK: - FINAL CONCLUSION
//
// `discard self` CAN work with ~Copyable elements IF:
// 1. The storage uses trivially-destructible backing (tuple, raw pointer)
// 2. The caller ALWAYS calls the consuming cleanup method
//
// HOWEVER, this doesn't solve the original problem because:
// - If the caller forgets to call cleanup(), deinit runs and leaks
// - We can't store a generic deinitializer because closures aren't trivially destructible
// - @convention(c) function pointers can't be generic over ~Copyable
//
// The fundamental issue is: to support `discard self`, we need trivially-destructible storage,
// but to properly clean up ~Copyable elements in deinit, we need a type-aware deinitializer,
// which requires either:
// a) A Swift closure (not trivially destructible - uses ARC)
// b) @_rawLayout (not trivially destructible)
// c) The type to be known at compile time (no generics)
//
// RECOMMENDATION: Accept that `discard self` cannot be used with generic ~Copyable storage.
// Use Option E + I from the research (make deinitialize package-internal, accept asymmetry).
