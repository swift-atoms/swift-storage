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
import Storage_Arena_Primitives
import Storage_Primitives_Test_Support

/// Test element with non-trivial stride for arena testing.
struct Payload: Equatable {
    var x: Int
    var y: UInt8
}

extension Storage<Payload>.Arena {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
    }
}

// MARK: - Unit Tests

extension Storage<Payload>.Arena.Test.Unit {
    @Test("Init creates arena with correct capacity")
    func initCapacity() {
        let arena = Storage<Payload>.Arena(capacity: 8)
        #expect(arena.capacity == 8)
        #expect(arena.allocated == .zero)
        #expect(arena.remaining == 8)
        #expect(arena.isEmpty)
    }

    @Test("Allocate returns sequential indices")
    func allocateSequential() {
        let arena = Storage<Payload>.Arena(capacity: 4)

        let slot0 = arena.allocate()
        let slot1 = arena.allocate()
        let slot2 = arena.allocate()

        #expect(slot0 != nil)
        #expect(slot1 != nil)
        #expect(slot2 != nil)
        #expect(slot0 != slot1)
        #expect(slot1 != slot2)
        #expect(arena.allocated == 3)
        #expect(arena.remaining == 1)
        #expect(arena.isEmpty == false)
    }

    @Test("Pointer access for read and write")
    func pointerAccess() {
        let arena = Storage<Payload>.Arena(capacity: 4)
        let slot = arena.allocate()!

        unsafe arena.pointer(at: slot).initialize(to: Payload(x: 42, y: 7))

        let value = unsafe arena.pointer(at: slot).pointee
        #expect(value == Payload(x: 42, y: 7))
    }

    @Test("Properties track allocation state")
    func properties() {
        let arena = Storage<Payload>.Arena(capacity: 3)

        #expect(arena.capacity == 3)
        #expect(arena.allocated == .zero)
        #expect(arena.remaining == 3)
        #expect(arena.isEmpty)

        _ = arena.allocate()

        #expect(arena.allocated == 1)
        #expect(arena.remaining == 2)
        #expect(arena.isEmpty == false)

        _ = arena.allocate()
        _ = arena.allocate()

        #expect(arena.allocated == 3)
        #expect(arena.remaining == .zero)
    }

    @Test("Deinitialize all resets arena")
    func deinitializeAll() {
        let arena = Storage<Payload>.Arena(capacity: 4)

        let slot0 = arena.allocate()!
        let slot1 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: Payload(x: 1, y: 2))
        unsafe arena.pointer(at: slot1).initialize(to: Payload(x: 3, y: 4))

        arena.deinitialize.all()

        #expect(arena.allocated == .zero)
        #expect(arena.isEmpty)
        #expect(arena.remaining == 4)
    }
}

// MARK: - Edge Case Tests

extension Storage<Payload>.Arena.Test.EdgeCase {
    @Test("Exhaustion returns nil")
    func exhaustion() {
        let arena = Storage<Payload>.Arena(capacity: 2)

        let slot0 = arena.allocate()
        let slot1 = arena.allocate()
        let slot2 = arena.allocate()

        #expect(slot0 != nil)
        #expect(slot1 != nil)
        #expect(slot2 == nil)
        #expect(arena.allocated == 2)
    }

    @Test("Allocate after deinitialize reuses storage")
    func allocateAfterDeinitialize() {
        let arena = Storage<Payload>.Arena(capacity: 2)

        let slot0 = arena.allocate()!
        let slot1 = arena.allocate()!
        unsafe arena.pointer(at: slot0).initialize(to: Payload(x: 1, y: 2))
        unsafe arena.pointer(at: slot1).initialize(to: Payload(x: 3, y: 4))

        arena.deinitialize.all()

        let newSlot0 = arena.allocate()
        let newSlot1 = arena.allocate()
        let newSlot2 = arena.allocate()

        #expect(newSlot0 != nil)
        #expect(newSlot1 != nil)
        #expect(newSlot2 == nil)
    }
}

// MARK: - Integration Tests

extension Storage<Payload>.Arena.Test.Integration {
    @Test("Typed element roundtrip")
    func typedRoundtrip() {
        let arena = Storage<Payload>.Arena(capacity: 8)
        var slots: [Index<Payload>] = []

        for i in 0..<5 {
            let slot = arena.allocate()!
            unsafe arena.pointer(at: slot).initialize(to: Payload(x: i * 10, y: UInt8(i)))
            slots.append(slot)
        }

        for (i, slot) in slots.enumerated() {
            let value = unsafe arena.pointer(at: slot).pointee
            #expect(value == Payload(x: i * 10, y: UInt8(i)))
        }

        arena.deinitialize.all()
    }

    @Test("Deinitialize all then reallocate full cycle")
    func fullCycle() {
        let arena = Storage<Payload>.Arena(capacity: 3)

        for cycle in 0..<3 {
            for i in 0..<3 {
                let slot = arena.allocate()!
                unsafe arena.pointer(at: slot).initialize(
                    to: Payload(x: cycle * 100 + i, y: UInt8(i))
                )
            }
            #expect(arena.allocate() == nil)
            arena.deinitialize.all()
            #expect(arena.isEmpty)
        }
    }
}
