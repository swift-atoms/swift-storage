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

import Finite_Bounded_Primitives
import Memory_Heap_Primitives
import Storage_Contiguous_Primitives
import Storage_Accessor_Primitives
import Storage_Error_Primitives
import Storage_Heap_Primitives
import Storage_Initialization_Primitives
import Storage_Inline_Primitives
import Storage_Primitive
import Storage_Primitives_Test_Support
import Testing

@Suite("Storage.Inline Tracked Operations")
struct StorageInlineTrackedTests {

    // MARK: - Initialize Tests

    @Test
    func `initialize next tracks linear discipline`() throws {
        var storage = Storage<Int>.Inline<8>()

        let slot0 = try storage.initialize.next(to: 10)
        #expect(Index<Int>(slot0) == .zero)
        #expect(storage.initialization.count == Index<Int>.Count(1))

        let slot1 = try storage.initialize.next(to: 20)
        #expect(Index<Int>(slot1) == 1)
        #expect(storage.initialization.count == Index<Int>.Count(2))

        storage.deinitialize.all()
    }

    @Test
    func `initialize and move via tracked API`() throws {
        var storage = Storage<Int>.Inline<8>()

        try storage.initialize.next(to: 42)
        #expect(storage.initialization.count == Index<Int>.Count(1))

        let value = try storage.move.last()
        #expect(value == 42)
        #expect(storage.isEmpty == true)
    }

    @Test
    func `multiple initialize then move in LIFO order`() throws {
        var storage = Storage<Int>.Inline<8>()

        for i in 0..<5 {
            try storage.initialize.next(to: i * 10)
        }
        #expect(storage.initialization.count == Index<Int>.Count(5))

        for i in (0..<5).reversed() {
            let value = try storage.move.last()
            #expect(value == i * 10)
        }
        #expect(storage.isEmpty == true)
    }

    @Test
    func `initialize returns correct slot indices`() throws {
        var storage = Storage<Int>.Inline<4>()

        for i in 0..<4 {
            let slot = try storage.initialize.next(to: i)
            #expect(Index<Int>(slot).underlying == Ordinal(UInt(i)))
        }

        storage.deinitialize.all()
    }

    // MARK: - Deinitialize Tests

    @Test
    func `deinitialize all via tracked API`() throws {
        var storage = Storage<Int>.Inline<8>()

        for i in 0..<5 {
            try storage.initialize.next(to: i)
        }

        storage.deinitialize.all()
        #expect(storage.isEmpty == true)
    }

    @Test
    func `deinitialize all via property accessor`() throws {
        var storage = Storage<Int>.Inline<8>()

        for i in 0..<3 {
            try storage.initialize.next(to: i)
        }

        storage.deinitialize.all()
        #expect(storage.isEmpty == true)
    }

    @Test
    func `deinitialize all cleans up class elements`() throws {
        final class Tracker: @unchecked Sendable {
            nonisolated(unsafe) static var count = 0
            init() { unsafe Self.count += 1 }
            deinit { unsafe Self.count -= 1 }
        }

        unsafe Tracker.count = 0

        var storage = Storage<Tracker>.Inline<4>()
        for _ in 0..<3 {
            try storage.initialize.next(to: Tracker())
        }

        unsafe #expect(Tracker.count == 3)
        storage.deinitialize.all()
        unsafe #expect(Tracker.count == 0)
        #expect(storage.isEmpty == true)
    }

    @Test
    func `deinitialize empty storage is no-op`() {
        var storage = Storage<Int>.Inline<8>()
        storage.deinitialize.all()
        #expect(storage.isEmpty == true)
    }

    // MARK: - capacity Tests

    @Test
    func `capacity matches compile-time count`() {
        let storage8 = Storage<Int>.Inline<8>()
        #expect(storage8.capacity == Index<Int>.Count(8))

        let storage1 = Storage<Int>.Inline<1>()
        #expect(storage1.capacity == Index<Int>.Count(1))

        let storage256 = Storage<Int>.Inline<256>()
        #expect(storage256.capacity == Index<Int>.Count(256))
    }

    // MARK: - copy(to: Heap) Tests

    @Test
    func `copy all to heap`() throws {
        var inline = Storage<Int>.Inline<8>()

        for i in 0..<4 {
            try inline.initialize.next(to: i * 5)
        }

        var heap = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(8))
        inline.copy(to: heap)
        heap.initialization = .linear(count: Index<Int>.Count(4))

        // Inline should still have values
        #expect(inline.initialization.count == Index<Int>.Count(4))

        // Heap should have copies
        for i in (0..<4).reversed() {
            let value = try heap.move.last()
            #expect(value == i * 5)
        }

        // Clean up inline
        inline.deinitialize.all()
    }

    @Test
    func `copy empty to heap is no-op`() {
        let inline = Storage<Int>.Inline<8>()
        var heap = Storage<Int>.Contiguous<Memory.Heap<Int>>.create(minimumCapacity: Index<Int>.Count(8))

        inline.copy(to: heap)
        #expect(heap.initialization.isEmpty == true)
    }

    // MARK: - Roundtrip Tests

    @Test
    func `full roundtrip: initialize, move, deinitialize`() throws {
        var storage = Storage<Int>.Inline<4>()

        // Fill completely
        for i in 0..<4 {
            try storage.initialize.next(to: i + 1)
        }
        #expect(storage.initialization.count == Index<Int>.Count(4))

        // Drain via move.last()
        #expect(try storage.move.last() == 4)
        #expect(try storage.move.last() == 3)
        #expect(storage.initialization.count == Index<Int>.Count(2))

        // Deinitialize remaining
        storage.deinitialize.all()
        #expect(storage.isEmpty == true)

        // Refill
        try storage.initialize.next(to: 99)
        #expect(storage.initialization.count == Index<Int>.Count(1))
        #expect(try storage.move.last() == 99)
    }

    // MARK: - Error Path Tests

    @Test
    func `initialize beyond capacity throws capacityExceeded`() throws {
        var storage = Storage<Int>.Inline<2>()
        try storage.initialize.next(to: 1)
        try storage.initialize.next(to: 2)
        #expect(throws: Storage<Int>.Error.capacityExceeded) {
            try storage.initialize.next(to: 3)
        }
        storage.deinitialize.all()
    }

    @Test
    func `move from empty throws empty`() {
        var storage = Storage<Int>.Inline<4>()
        #expect(throws: Storage<Int>.Error.empty) {
            try storage.move.last()
        }
    }
}
