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

import Testing
import Storage_Pool_Primitives
import Storage_Primitives_Test_Support

/// Test element with non-trivial stride for pool testing.
struct Node: Equatable {
    var value: Int
    var tag: UInt8
}

@Suite("Storage.Pool")
struct StoragePoolTests {

    // MARK: - Unit Tests

    @Test
    func `init creates pool with specified capacity`() throws {
        let pool = try Storage<Node>.Pool(capacity: 16)
        #expect(pool.capacity == 16)
        #expect(pool.allocated == 0)
        #expect(pool.available == 16)
        #expect(pool.isExhausted == false)
        #expect(pool.isEmpty == true)
    }

    @Test
    func `allocate returns valid index`() throws {
        let pool = try Storage<Node>.Pool(capacity: 16)
        let slot = try pool.allocate()
        #expect(pool.allocated == 1)
        #expect(pool.isEmpty == false)
        unsafe pool.pointer(at: slot).initialize(to: Node(value: 42, tag: 0))
        _ = unsafe pool.pointer(at: slot).move()
        try pool.deallocate(at: slot)
    }

    @Test
    func `allocate returns sequential indices`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)
        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        let s2 = try pool.allocate()

        #expect(s0 == 0)
        #expect(s1 == 1)
        #expect(s2 == 2)
        #expect(pool.allocated == 3)
        #expect(pool.available == 1)

        try pool.deallocate(at: s0)
        try pool.deallocate(at: s1)
        try pool.deallocate(at: s2)
    }

    @Test
    func `deallocate returns slot to pool`() throws {
        let pool = try Storage<Node>.Pool(capacity: 16)
        let slot = try pool.allocate()
        try pool.deallocate(at: slot)
        #expect(pool.allocated == 0)
        #expect(pool.available == 16)
        #expect(pool.isEmpty == true)
    }

    @Test
    func `capacity property returns total capacity`() throws {
        let pool = try Storage<Node>.Pool(capacity: 100)
        #expect(pool.capacity == 100)
    }

    @Test
    func `pointer(at:) returns usable typed pointer`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)
        let slot = try pool.allocate()

        let node = Node(value: 42, tag: 7)
        unsafe pool.pointer(at: slot).initialize(to: node)
        let readBack: Node = unsafe pool.pointer(at: slot).pointee
        #expect(readBack == node)
        _ = unsafe pool.pointer(at: slot).move()

        try pool.deallocate(at: slot)
    }

    // MARK: - Edge Cases

    @Test
    func `init with zero capacity throws`() {
        #expect(throws: Storage<Node>.Pool.Error.invalidCapacity) {
            _ = try Storage<Node>.Pool(capacity: 0)
        }
    }

    @Test
    func `allocate throws when exhausted`() throws {
        let pool = try Storage<Node>.Pool(capacity: 2)
        _ = try pool.allocate()
        _ = try pool.allocate()
        #expect(throws: Storage<Node>.Pool.Error.exhausted(capacity: 2)) {
            _ = try pool.allocate()
        }
    }

    @Test
    func `deallocate detects double free`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)
        let slot = try pool.allocate()
        try pool.deallocate(at: slot)
        #expect(throws: Storage<Node>.Pool.Error.doubleFree) {
            try pool.deallocate(at: slot)
        }
    }

    @Test
    func `isExhausted with virgin cursor and free list`() throws {
        let pool = try Storage<Node>.Pool(capacity: 2)

        let s0 = try pool.allocate()
        #expect(pool.isExhausted == false)

        _ = try pool.allocate()
        #expect(pool.isExhausted == true)

        try pool.deallocate(at: s0)
        #expect(pool.isExhausted == false)
    }

    // MARK: - Integration

    @Test
    func `typed element roundtrip`() throws {
        let pool = try Storage<Node>.Pool(capacity: 8)

        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        let s2 = try pool.allocate()

        unsafe pool.pointer(at: s0).initialize(to: Node(value: 100, tag: 1))
        unsafe pool.pointer(at: s1).initialize(to: Node(value: 200, tag: 2))
        unsafe pool.pointer(at: s2).initialize(to: Node(value: 300, tag: 3))

        #expect(unsafe pool.pointer(at: s0).pointee == Node(value: 100, tag: 1))
        #expect(unsafe pool.pointer(at: s1).pointee == Node(value: 200, tag: 2))
        #expect(unsafe pool.pointer(at: s2).pointee == Node(value: 300, tag: 3))

        _ = unsafe pool.pointer(at: s0).move()
        _ = unsafe pool.pointer(at: s1).move()
        _ = unsafe pool.pointer(at: s2).move()

        try pool.deallocate(at: s0)
        try pool.deallocate(at: s1)
        try pool.deallocate(at: s2)
    }

    @Test
    func `LIFO reuse: last freed is first allocated`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)

        let a = try pool.allocate()
        let b = try pool.allocate()

        try pool.deallocate(at: b)
        try pool.deallocate(at: a)

        let first = try pool.allocate()
        #expect(first == a)
        let second = try pool.allocate()
        #expect(second == b)

        try pool.deallocate(at: first)
        try pool.deallocate(at: second)
    }

    @Test
    func `deinitialize all resets pool`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)

        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        unsafe pool.pointer(at: s0).initialize(to: Node(value: 10, tag: 0))
        unsafe pool.pointer(at: s1).initialize(to: Node(value: 20, tag: 0))

        #expect(pool.allocated == 2)

        pool.deinitialize.all()

        #expect(pool.allocated == 0)
        #expect(pool.available == 4)
        #expect(pool.isExhausted == false)
    }

    @Test
    func `copy creates independent pool`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)

        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        unsafe pool.pointer(at: s0).initialize(to: Node(value: 100, tag: 1))
        unsafe pool.pointer(at: s1).initialize(to: Node(value: 200, tag: 2))

        let copy = pool.copy()

        #expect(copy.allocated == 2)
        #expect(copy.capacity == 4)
        #expect(unsafe copy.pointer(at: s0).pointee == Node(value: 100, tag: 1))
        #expect(unsafe copy.pointer(at: s1).pointee == Node(value: 200, tag: 2))

        // Verify independence
        unsafe pool.pointer(at: s0).pointee = Node(value: 999, tag: 0)
        #expect(unsafe copy.pointer(at: s0).pointee == Node(value: 100, tag: 1))

        // Both pools deinit automatically
    }

    @Test
    func `allocate all then deallocate all`() throws {
        let pool = try Storage<Node>.Pool(capacity: 4)
        var slots: [Index<Node>] = []

        for _ in 0..<4 {
            slots.append(try pool.allocate())
        }
        #expect(pool.isExhausted == true)

        for slot in slots {
            try pool.deallocate(at: slot)
        }
        #expect(pool.allocated == 0)
        #expect(pool.available == 4)
    }
}
