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

/// Test element with non-trivial stride for inline pool testing.
struct InlineNode: Equatable {
    var value: Int
    var tag: UInt8
}

@Suite("Storage.Pool.Inline Tests")
struct StoragePoolInlineTests {

    // MARK: - Init

    @Test("Init creates empty pool")
    func initEmpty() {
        var pool = Storage<InlineNode>.Pool.Inline<8>()
        #expect(pool.isEmpty == true)
        #expect(pool.allocated == .zero)
        #expect(pool.available == 8)
        #expect(pool.isExhausted == false)
        _ = pool
    }

    // MARK: - Allocate

    @Test("Allocate returns valid bounded index")
    func allocateValid() throws {
        var pool = Storage<InlineNode>.Pool.Inline<8>()
        let slot = try pool.allocate()
        #expect(pool.allocated == 1)
        #expect(pool.isEmpty == false)
        unsafe pool.pointer(at: slot).initialize(to: InlineNode(value: 42, tag: 0))
        _ = unsafe pool.pointer(at: slot).move()
        try pool.deallocate(at: slot)
    }

    @Test("Allocate returns sequential indices")
    func allocateSequential() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()
        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        let s2 = try pool.allocate()

        #expect(Index<InlineNode>(s0) == 0)
        #expect(Index<InlineNode>(s1) == 1)
        #expect(Index<InlineNode>(s2) == 2)
        #expect(pool.allocated == 3)
        #expect(pool.available == 1)

        try pool.deallocate(at: s0)
        try pool.deallocate(at: s1)
        try pool.deallocate(at: s2)
    }

    // MARK: - Pointer

    @Test("Pointer write/read roundtrip via bounded pointer")
    func pointerRoundtrip() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()
        let slot = try pool.allocate()

        let node = InlineNode(value: 42, tag: 7)
        unsafe pool.pointer(at: slot).initialize(to: node)
        let readBack: InlineNode = unsafe (pool.pointer(at: slot) as UnsafePointer<InlineNode>).pointee
        #expect(readBack == node)
        _ = unsafe pool.pointer(at: slot).move()

        try pool.deallocate(at: slot)
    }

    // MARK: - Deallocate

    @Test("Deallocate returns slot and updates counts")
    func deallocateCounts() throws {
        var pool = Storage<InlineNode>.Pool.Inline<8>()
        let slot = try pool.allocate()
        try pool.deallocate(at: slot)
        #expect(pool.allocated == .zero)
        #expect(pool.available == 8)
        #expect(pool.isEmpty == true)
    }

    // MARK: - Slot Reuse

    @Test("Slot reuse after deallocate")
    func slotReuse() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()

        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        try pool.deallocate(at: s0)

        let reused = try pool.allocate()
        #expect(Index<InlineNode>(reused) == Index<InlineNode>(s0))

        try pool.deallocate(at: s1)
        try pool.deallocate(at: reused)
    }

    // MARK: - Exhaustion

    @Test("Allocate throws when exhausted")
    func exhaustion() throws {
        var pool = Storage<InlineNode>.Pool.Inline<2>()
        _ = try pool.allocate()
        _ = try pool.allocate()
        #expect(throws: Storage<InlineNode>.Pool.Error.exhausted(capacity: 2)) {
            _ = try pool.allocate()
        }
    }

    // MARK: - Double Free

    @Test("Deallocate detects double free")
    func doubleFree() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()
        let slot = try pool.allocate()
        try pool.deallocate(at: slot)
        #expect(throws: Storage<InlineNode>.Pool.Error.doubleFree) {
            try pool.deallocate(at: slot)
        }
    }

    // MARK: - Deinitialize

    @Test("Deinitialize all resets pool")
    func deinitializeAll() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()

        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        unsafe pool.pointer(at: s0).initialize(to: InlineNode(value: 10, tag: 0))
        unsafe pool.pointer(at: s1).initialize(to: InlineNode(value: 20, tag: 0))

        #expect(pool.allocated == 2)

        pool.deinitialize.all()

        #expect(pool.allocated == .zero)
        #expect(pool.available == 4)
        #expect(pool.isExhausted == false)
        #expect(pool.isEmpty == true)
    }

    // MARK: - Full Cycle

    @Test("Full cycle: allocate all, deinitialize, reallocate")
    func fullCycle() throws {
        var pool = Storage<InlineNode>.Pool.Inline<4>()

        for cycle in 0..<3 {
            var slots: [Index<InlineNode>.Bounded<4>] = []
            for i in 0..<4 {
                let slot = try pool.allocate()
                unsafe pool.pointer(at: slot).initialize(
                    to: InlineNode(value: cycle * 100 + i, tag: UInt8(i))
                )
                slots.append(slot)
            }
            #expect(pool.isExhausted == true)

            for (i, slot) in slots.enumerated() {
                let value = unsafe (pool.pointer(at: slot) as UnsafePointer<InlineNode>).pointee
                #expect(value == InlineNode(value: cycle * 100 + i, tag: UInt8(i)))
            }

            pool.deinitialize.all()
            #expect(pool.isEmpty == true)
        }
    }

    // MARK: - Small Element

    @Test("Small element type works (no stride constraint)")
    func smallElement() throws {
        var pool = Storage<UInt8>.Pool.Inline<4>()
        let s0 = try pool.allocate()
        let s1 = try pool.allocate()
        unsafe pool.pointer(at: s0).initialize(to: 0xFF)
        unsafe pool.pointer(at: s1).initialize(to: 0x42)
        #expect(unsafe (pool.pointer(at: s0) as UnsafePointer<UInt8>).pointee == 0xFF)
        #expect(unsafe (pool.pointer(at: s1) as UnsafePointer<UInt8>).pointee == 0x42)
        _ = unsafe pool.pointer(at: s0).move()
        _ = unsafe pool.pointer(at: s1).move()
        try pool.deallocate(at: s0)
        try pool.deallocate(at: s1)
    }

    // MARK: - Typed Roundtrip

    @Test("Typed element roundtrip")
    func typedRoundtrip() throws {
        var pool = Storage<InlineNode>.Pool.Inline<8>()
        var slots: [Index<InlineNode>.Bounded<8>] = []

        for i in 0..<5 {
            let slot = try pool.allocate()
            unsafe pool.pointer(at: slot).initialize(to: InlineNode(value: i * 10, tag: UInt8(i)))
            slots.append(slot)
        }

        for (i, slot) in slots.enumerated() {
            let value = unsafe (pool.pointer(at: slot) as UnsafePointer<InlineNode>).pointee
            #expect(value == InlineNode(value: i * 10, tag: UInt8(i)))
        }

        pool.deinitialize.all()
    }
}
