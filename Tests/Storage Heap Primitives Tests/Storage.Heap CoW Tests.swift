// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Storage_Heap_Primitives
import Storage_Primitives_Test_Support
import Testing

/// Copy-on-write value-semantics tests for the conditionally-`Copyable`
/// `Storage.Contiguous<Memory.Heap>` (the stdlib `Array` model — wave 4).
///
/// `Storage.Contiguous<Memory.Heap>` is `Copyable` when `Element: Copyable`; a value-copy shares the
/// backing `Buffer` (a class) shallowly, and internal copy-on-write restores value
/// semantics: the first mutation of a shared Heap copies the initialized elements
/// into a fresh buffer, leaving the other copy untouched.
@Suite("Storage.Heap Copy-on-Write Tests")
struct StorageHeapCoWTests {

    // MARK: - Value Semantics (the load-bearing hypothesis)

    /// A value-copy must not affect the original.
    ///
    /// The canonical CoW value-semantics check: `move.last()` removes the copy's
    /// last element; the original's slot must be unchanged because CoW deep-copied
    /// before the move.
    @Test
    func `value copy then mutate copy leaves original unchanged`() throws {
        var a = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(8))
        try a.initialize.next(to: 42)
        #expect(a.initialization.count == Index<Int>.Count(1))

        // Value-copy: shares the backing buffer shallowly (copy deferred).
        var b = a

        // Mutate the copy: move out its last element. This triggers CoW on `b`.
        let moved = try b.move.last()
        #expect(moved == 42)

        // Original is UNCHANGED — its slot still holds 42 and its count is still 1.
        #expect(a.initialization.count == Index<Int>.Count(1))
        let originalSlotValue = unsafe a.pointer(at: .zero).pointee
        #expect(originalSlotValue == 42)

        // The copy reflects the mutation — it is now empty.
        #expect(b.isEmpty == true)

        // Drain the original so the backing buffer's deinit cleans up its slot.
        _ = try a.move.last()
    }

    /// In-place slot mutation on a copy (via append) must not perturb the original.
    @Test
    func `appending to a copy does not grow the original`() throws {
        var a = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(8))
        try a.initialize.next(to: 100)

        var b = a
        // Append to the copy — initialize-path mutation, triggers CoW on `b`.
        try b.initialize.next(to: 200)

        // Original still has exactly one element, value 100.
        #expect(a.initialization.count == Index<Int>.Count(1))
        #expect(unsafe a.pointer(at: .zero).pointee == 100)

        // Copy has two elements: [100, 200] in its own buffer.
        #expect(b.initialization.count == Index<Int>.Count(2))
        #expect(unsafe b.pointer(at: .zero).pointee == 100)
        #expect(unsafe b.pointer(at: Index<Int>(1)).pointee == 200)

        // Drain both so the backing buffers' deinits clean up.
        b.deinitialize.all()
        _ = try a.move.last()
    }

    // MARK: - Copy Deferred to Mutation

    /// A plain value-copy (`let b = a`) defers the buffer copy until first mutation.
    ///
    /// We observe this through the uniqueness primitive: after the copy the buffer
    /// is shared (`isUnique == false`); after a mutation on the copy, the copy owns
    /// a fresh, unique buffer.
    @Test
    func `plain copy is deferred; copy happens on mutation`() throws {
        var a = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(8))
        try a.initialize.next(to: 7)

        // Before any copy, `a` solely owns its buffer.
        #expect(a.isUnique == true)

        var b = a

        // After the value-copy the buffer is SHARED — no copy was made yet.
        #expect(a.isUnique == false)
        #expect(b.isUnique == false)

        // Mutate `b`. The CoW accessor calls ensureUnique() → `b` gets a fresh buffer.
        try b.initialize.next(to: 9)

        // `a` is sole owner again (b moved off the shared buffer); `b` owns its own.
        #expect(a.isUnique == true)
        #expect(b.isUnique == true)

        // Cleanup.
        b.deinitialize.all()
        _ = try a.move.last()
    }

    /// `ensureUnique()` returns `false` when already unique (no copy), and `true`
    /// exactly once when a shared buffer is made unique.
    @Test
    func `ensureUnique reports whether a copy was made`() throws {
        var a = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(4))
        try a.initialize.next(to: 1)

        // Sole owner — no copy needed.
        #expect(a.ensureUnique() == false)

        var b = a
        // Shared — calling ensureUnique() on `b` makes a copy.
        #expect(b.ensureUnique() == true)
        // Now both are unique; a second call is a no-op.
        #expect(b.ensureUnique() == false)
        #expect(a.ensureUnique() == false)

        // The copy preserved the element.
        #expect(unsafe b.pointer(at: .zero).pointee == 1)
        #expect(unsafe a.pointer(at: .zero).pointee == 1)

        b.deinitialize.all()
        _ = try a.move.last()
    }

    // MARK: - Independent Lifecycle After CoW

    /// After CoW, deinitializing the copy must not deinitialize the original's
    /// elements (independent buffers, independent slot lifecycles).
    @Test
    func `CoW preserves independent element lifecycle`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var deinitCount = 0
            let id: Int
            init(id: Int) { self.id = id }
            deinit { unsafe Self.deinitCount += 1 }
        }

        unsafe Tracker.deinitCount = 0

        do {
            var a = Storage<Tracker>.Contiguous<Memory.Heap<Tracker>>.create(minimumCapacity: Index<Tracker>.Count(4))
            try a.initialize.next(to: Tracker(id: 1))

            var b = a
            // Append to copy: CoW copies the shared Tracker reference into b's buffer
            // (the class ref is retained, not the object cloned — element is Copyable
            // because the *reference* is Copyable). Both buffers now hold the ref.
            try b.initialize.next(to: Tracker(id: 2))

            // Drain the copy completely.
            b.deinitialize.all()
            #expect(b.isEmpty == true)

            // The original still has its element — reading it must be valid (the
            // shared Tracker(id:1) ref is alive because `a`'s buffer still holds it).
            #expect(a.initialization.count == Index<Tracker>.Count(1))
            #expect(unsafe a.pointer(at: .zero).pointee.id == 1)

            a.deinitialize.all()
        }

        // Two distinct Tracker objects were created (id 1 and id 2); both deinit
        // exactly once. CoW retained references, it did not duplicate objects, and
        // draining each buffer released its retained references without double-free.
        unsafe #expect(Tracker.deinitCount == 2)
    }
}
