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
import Storage_Arena_Inline_Primitives
import Storage_Primitives_Test_Support

/// Test element with non-trivial stride for inline arena testing.
struct InlinePayload: Equatable {
    var x: Int
    var y: UInt8
}

@Suite("Storage.Arena.Inline Tests")
struct StorageArenaInlineTests {

    // MARK: - Init

    @Test
    func `Init creates empty arena`() {
        var arena = Storage<InlinePayload>.Arena.Inline<8>()
        #expect(arena.isEmpty == true)
        #expect(arena.allocated == .zero)
        #expect(arena.remaining == 8)
        _ = arena
    }

    // MARK: - Allocate

    @Test
    func `Allocate returns sequential bounded indices`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()

        let slot0 = arena.allocate()
        let slot1 = arena.allocate()
        let slot2 = arena.allocate()

        #expect(slot0 != nil)
        #expect(slot1 != nil)
        #expect(slot2 != nil)
        #expect(arena.allocated == 3)
        #expect(arena.remaining == 1)
        #expect(arena.isEmpty == false)
    }

    // MARK: - Pointer

    @Test
    func `Pointer write/read roundtrip via bounded pointer`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()
        let slot = arena.allocate()!

        unsafe arena.pointer(at: slot).initialize(to: InlinePayload(x: 42, y: 7))

        let value = unsafe arena.pointer(at: slot).pointee
        #expect(value == InlinePayload(x: 42, y: 7))
    }

    // MARK: - Properties

    @Test
    func `Properties track allocation state`() {
        var arena = Storage<InlinePayload>.Arena.Inline<3>()

        #expect(arena.allocated == .zero)
        #expect(arena.remaining == 3)
        #expect(arena.isEmpty == true)

        _ = arena.allocate()

        #expect(arena.allocated == 1)
        #expect(arena.remaining == 2)
        #expect(arena.isEmpty == false)

        _ = arena.allocate()
        _ = arena.allocate()

        #expect(arena.allocated == 3)
        #expect(arena.remaining == .zero)
    }

    // MARK: - Exhaustion

    @Test
    func `Exhaustion returns nil`() {
        var arena = Storage<InlinePayload>.Arena.Inline<2>()

        let slot0 = arena.allocate()
        let slot1 = arena.allocate()
        let slot2 = arena.allocate()

        #expect(slot0 != nil)
        #expect(slot1 != nil)
        #expect(slot2 == nil)
        #expect(arena.allocated == 2)
    }

    // MARK: - Deinitialize

    @Test
    func `Deinitialize all resets arena`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()

        let slot0 = arena.allocate()!
        let slot1 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: InlinePayload(x: 1, y: 2))
        unsafe arena.pointer(at: slot1).initialize(to: InlinePayload(x: 3, y: 4))

        arena.deinitialize.all()

        #expect(arena.allocated == .zero)
        #expect(arena.isEmpty == true)
        #expect(arena.remaining == 4)
    }

    // MARK: - Unallocate

    @Test
    func `Unallocate rolls back most recent allocation`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()

        let slot0 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: InlinePayload(x: 1, y: 2))

        let slot1 = arena.allocate()!
        // Simulate failed initialization — roll back
        arena.unallocate(slot1)

        #expect(arena.allocated == 1)
        #expect(arena.remaining == 3)
    }

    @Test
    func `Unallocate then reallocate reuses index`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()

        let slot0 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: InlinePayload(x: 1, y: 2))

        let slot1 = arena.allocate()!
        arena.unallocate(slot1)

        let slot1Again = arena.allocate()!
        #expect(Index<InlinePayload>(slot1) == Index<InlinePayload>(slot1Again))
    }

    @Test
    func `Unallocate after deinitialize all cycle`() {
        var arena = Storage<InlinePayload>.Arena.Inline<4>()

        let slot0 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: InlinePayload(x: 1, y: 2))
        arena.deinitialize.all()

        let newSlot = arena.allocate()!
        arena.unallocate(newSlot)

        #expect(arena.allocated == .zero)
        #expect(arena.isEmpty == true)
    }

    // MARK: - Full Cycle

    @Test
    func `Full cycle: allocate all, deinitialize, reallocate`() {
        var arena = Storage<InlinePayload>.Arena.Inline<3>()

        for cycle in 0..<3 {
            for i in 0..<3 {
                let slot = arena.allocate()!
                unsafe arena.pointer(at: slot).initialize(
                    to: InlinePayload(x: cycle * 100 + i, y: UInt8(i))
                )
            }
            #expect(arena.allocate() == nil)
            arena.deinitialize.all()
            #expect(arena.isEmpty == true)
        }
    }

    // MARK: - Typed Roundtrip

    @Test
    func `Typed element roundtrip`() {
        var arena = Storage<InlinePayload>.Arena.Inline<8>()
        var slots: [Index<InlinePayload>.Bounded<8>] = []

        for i in 0..<5 {
            let slot = arena.allocate()!
            unsafe arena.pointer(at: slot).initialize(to: InlinePayload(x: i * 10, y: UInt8(i)))
            slots.append(slot)
        }

        for (i, slot) in slots.enumerated() {
            let value = unsafe arena.pointer(at: slot).pointee
            #expect(value == InlinePayload(x: i * 10, y: UInt8(i)))
        }

        arena.deinitialize.all()
    }
}
