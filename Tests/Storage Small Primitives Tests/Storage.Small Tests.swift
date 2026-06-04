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

import Index_Primitives
import Memory_Heap_Primitives
import Storage_Inline_Primitives
import Storage_Primitive
import Storage_Small_Primitives
import Testing

@Suite("Storage.Small Tests")
struct StorageSmallTests {

    // MARK: - Creation

    @Test
    func `empty Small starts inline`() {
        let small = Storage<Int>.Small<8>()
        #expect(small.isSpilled == false)
        #expect(small.capacity == Index<Int>.Count(UInt(8)))
    }

    @Test
    func `create within inline capacity stays inline`() {
        let small = Storage<Int>.Small<8>.create(minimumCapacity: Index<Int>.Count(UInt(4)))
        #expect(small.isSpilled == false)
    }

    @Test
    func `create above inline capacity allocates the heap arm`() {
        let small = Storage<Int>.Small<4>.create(minimumCapacity: Index<Int>.Count(UInt(64)))
        #expect(small.isSpilled == true)
        #expect(small.capacity >= Index<Int>.Count(UInt(64)))
    }

    // MARK: - The Store seam (inline arm)

    @Test
    func `initialize, read, and move through the inline seam`() {
        var small = Storage<Int>.Small<8>()
        small.initialize(at: 0, to: 42)
        small.initialize(at: 1, to: 99)
        #expect(small[0] == 42)
        #expect(small[1] == 99)
        let moved = small.move(at: 1)
        #expect(moved == 99)
        #expect(small[0] == 42)
    }

    @Test
    func `subscript set mutates in place (inline arm)`() {
        var small = Storage<Int>.Small<8>()
        small.initialize(at: 0, to: 1)
        small[0] = 7
        #expect(small[0] == 7)
    }

    // MARK: - The Store seam (heap arm)

    @Test
    func `initialize, read, and move through the heap seam`() {
        var small = Storage<Int>.Small<2>.create(minimumCapacity: Index<Int>.Count(UInt(16)))
        #expect(small.isSpilled == true)
        small.initialize(at: 0, to: 5)
        small.initialize(at: 3, to: 8)
        #expect(small[0] == 5)
        #expect(small[3] == 8)
        let moved = small.move(at: 0)
        #expect(moved == 5)
    }

    // MARK: - ~Copyable elements

    @Test
    func `inline seam handles ~Copyable elements with correct move-out`() {
        struct Box: ~Copyable { var payload: Int }
        var small = Storage<Box>.Small<8>()
        small.initialize(at: 0, to: Box(payload: 7))
        let moved = small.move(at: 0)
        #expect(moved.payload == 7)
    }
}
